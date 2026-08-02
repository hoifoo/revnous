# LAYOUT-04 CI gate: freezes today's TOC-off /blog/:slug rendering across five
# curated fixtures covering images, tables, code blocks, an FAQ section, and a
# minimal body. A failure here means an existing post's rendering changed.
#
# Baselines regenerate with:
#   UPDATE_GOLDEN=1 bundle exec rspec spec/requests/blogs_golden_master_spec.rb
# Regeneration is a deliberate act requiring the resulting git diff to be
# reviewed — it is never a way to make a red build green.
require 'rails_helper'

RSpec.describe "Blog show golden master (LAYOUT-04)", type: :request do
  # Absolute, not relative — `1.day.ago` would change the JSON-LD
  # datePublished on every run. Distinct values also make the related-
  # articles `published_at DESC` ordering total, so fixture ordering is
  # deterministic.
  BASE_TIME = Time.utc(2026, 1, 15, 10, 0, 0)

  # Bodies composed against this app's real Blog::ALLOWED_TAGS surface
  # (RESEARCH.md Pattern 4). No Active Storage attach anywhere — blob keys
  # are randomized per run and would poison the baseline; "images" coverage
  # means <img> tags inside body HTML, the path that actually flows through
  # sanitize.
  FIXTURES = {
    "images_post"  => '<h2>Gallery</h2><figure><img src="/a.png" alt="A&nbsp;B" width="640"><figcaption>Cap &mdash; here</figcaption></figure><p>After</p>',
    "tables_post"  => '<h2>Data</h2><table><colgroup><col width="50"></colgroup><thead><tr><th scope="col">A &amp; B</th></tr></thead><tbody><tr><td rowspan="2">x</td></tr></tbody><tfoot><tr><td>f</td></tr></tfoot></table>',
    "code_post"    => "<h2>Usage</h2><pre><code>a &lt; b &amp;&amp; c &gt; d\n  indent\n</code></pre><p>inline <code>x = 1</code></p>",
    "faq_post"     => "<h2>Overview</h2><p>Intro &hellip; text.</p><h3>Detail</h3><p>More.</p>",
    "minimal_post" => "<p>Just a sentence.</p>"
  }.freeze

  before do
    FIXTURES.each_with_index do |(slug, body), i|
      attrs = {
        slug: slug,
        title: slug.titleize,
        body: body,
        published_at: BASE_TIME - i.days,
        toc_enabled: false,
        excerpt: (slug == "minimal_post" ? nil : "Short excerpt")
      }
      blog = create(:blog, **attrs)
      # update_column, not update: bypasses parse_faq_schema and leaves
      # updated_at untouched, keeping the JSON-LD dateModified pinned
      # (matches spec/requests/blogs_spec.rb:110-122).
      blog.update_column(:faq_schema, '[{"question":"Q?","answer":"A."}]') if slug == "faq_post"
    end
  end

  FIXTURES.each_key do |slug|
    describe "GET /blog/#{slug} with toc_enabled: false" do
      before { get blog_path(slug) }

      it "renders the article region byte-for-byte identically to the baseline" do
        expect(response).to have_http_status(:ok)
        match_golden!("#{slug}.article", article_region(response.body))
      end

      it "renders the full page identically to the baseline (volatility normalized)" do
        match_golden!("#{slug}.page", normalize_html(response.body))
      end

      it "emits no toc- anchor ids at all" do
        expect(response.body.scan('id="toc-').length).to eq(0)
      end
    end
  end
end
