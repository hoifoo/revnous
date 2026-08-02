# Golden-master comparison for LAYOUT-04 (Phase 1 regression baseline).
#
# Two layers, deliberately different strictness:
#   Layer A (`article_region`) — byte-exact on the single `div.prose` element.
#     This is the only markup this project's TOC/layout work actually touches,
#     so it stays exact with zero normalization.
#   Layer B (`normalize_html`) — the full page, with the volatility sources
#     below scrubbed first. Full-page exactness would false-fail on every
#     Tailwind/esbuild rebuild; normalization is what makes this layer usable
#     as a wrapper/layout regression gate for Phase 2+ without being noisy.
#
# Regenerate baselines deliberately, never blindly:
#   UPDATE_GOLDEN=1 bundle exec rspec spec/requests/blogs_golden_master_spec.rb
# then review the resulting git diff under spec/fixtures/golden_master/ before
# committing — a diff there means an existing post's rendering changed.
module GoldenMaster
  DIR = Rails.root.join("spec/fixtures/golden_master")

  # Verified volatility sources in this app's actual test-env /blog/:slug
  # response (2026-08-02, RESEARCH.md Pitfall 5):
  #   1. Propshaft asset digest    /assets/application-a812b469.css
  #      — changes on every Tailwind/esbuild rebuild
  #   2. ISO-8601 timestamps in JSON-LD, derived from published_at/updated_at
  #   3. The literal host injected by spec/support/devise.rb's `host!` call,
  #      not by any per-spec setup
  # (Related-articles ordering, the fourth verified source, is made
  # deterministic via distinct absolute published_at values in the spec
  # fixtures rather than normalized here.)
  NORMALIZERS = [
    [ %r{/assets/([\w-]+?)-[0-9a-f]{8,}\.(css|js)}, '/assets/\1-DIGEST.\2' ],
    [ /\d{4}-\d{2}-\d{2}T[\d:]{8}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?/, "TIMESTAMP" ],
    [ %r{http://www\.example\.com}, "HOST" ]
  ].freeze

  def normalize_html(html)
    NORMALIZERS.reduce(html.dup) { |acc, (re, sub)| acc.gsub(re, sub) }
  end

  # Layer A: article content region only. Nokogiri::HTML5, not HTML4 — the
  # view's `sanitize` call uses the HTML5 vendor, and parsing its output with
  # the wrong vendor silently decodes entities like &nbsp;/&mdash;/&hellip;
  # (RESEARCH.md Pitfall 1).
  def article_region(html)
    node = Nokogiri::HTML5(html).at_css("div.prose")
    raise "GoldenMaster#article_region: no div.prose found — the article region markup is missing or its selector changed" if node.nil?

    node.to_html
  end

  def match_golden!(name, actual)
    path = DIR.join("#{name}.html")

    if ENV["UPDATE_GOLDEN"]
      FileUtils.mkdir_p(DIR)
      path.write(actual)
      skip "golden master #{name} regenerated at #{path} — review the diff, then rerun without UPDATE_GOLDEN"
      return
    end

    raise "Missing golden master #{path}. Regenerate with: UPDATE_GOLDEN=1 bundle exec rspec spec/requests/blogs_golden_master_spec.rb" unless path.exist?

    expect(actual).to eq(path.read)
  end
end

RSpec.configure { |c| c.include GoldenMaster, type: :request }
