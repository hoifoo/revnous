module BlogsHelper
  MIN_TOC_ENTRIES = 3 # TOC-04, inclusive at the boundary (D-12)

  ArticleContent = Struct.new(:html, :toc_entries, keyword_init: true) do
    def toc? = toc_entries.any?
  end

  # SECURITY: `body` is sanitized here with Blog::ALLOWED_TAGS/ALLOWED_ATTRIBUTES
  # before any mutation. The only downstream mutation is adding `id`
  # attributes to h2/h3 nodes, where the id value is `parameterize` output
  # constrained to [a-z0-9-] and always `toc-` prefixed. No author markup is
  # reintroduced and no allowlist is widened.
  def blog_article(blog)
    sanitized = sanitize(blog.body, tags: Blog::ALLOWED_TAGS, attributes: Blog::ALLOWED_ATTRIBUTES)
    return ArticleContent.new(html: sanitized, toc_entries: []) unless blog.toc_enabled?

    toc = Blog::TableOfContents.call(sanitized) # the ONE parse (Phase 1 D-03)
    visible = visible_toc_entries(toc.entries, blog.toc_overrides)

    # D-11: ids stay on the headings even when suppressed, so deep links survive.
    return ArticleContent.new(html: toc.to_html.html_safe, toc_entries: []) if visible.size < MIN_TOC_ENTRIES

    ArticleContent.new(html: toc.to_html.html_safe, toc_entries: visible)
  end

  # SECURITY: sanitized_html is already the output of the view-level
  # `sanitize` helper using Blog::ALLOWED_TAGS/ALLOWED_ATTRIBUTES. The only
  # mutation applied here is adding `id` attributes to h2/h3 nodes, where the
  # id value is `parameterize` output constrained to [a-z0-9-] and always
  # `toc-` prefixed. No author markup is reintroduced and no allowlist is
  # widened. Enforced by spec/requests/blogs_toc_spec.rb and
  # spec/requests/blogs_golden_master_spec.rb.
  def blog_body_with_toc_anchors(blog, sanitized_html)
    return sanitized_html unless blog.toc_enabled?

    Blog::TableOfContents.call(sanitized_html).to_html.html_safe
  end

  private

  # D-09/D-10: hide-only, keyed by anchor. Pitfall 6: cast, never truthiness-test.
  def visible_toc_entries(entries, overrides)
    overrides = overrides.presence || {}
    caster = ActiveModel::Type::Boolean.new
    entries.reject { |e| caster.cast(overrides.dig(e.anchor, "hidden")) }
  end
end
