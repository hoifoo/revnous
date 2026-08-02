module BlogsHelper
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
end
