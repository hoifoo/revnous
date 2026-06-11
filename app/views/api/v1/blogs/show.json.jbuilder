json.partial! "api/v1/blogs/blog", blog: @blog

# Sanitized HTML (model strips disallowed tags on save).
json.content_html @blog.body
json.faq @blog.faq_pairs
