json.id blog.id
json.slug blog.slug
json.title blog.title
json.excerpt blog.excerpt
json.category blog.category
json.author blog.author&.full_name || "Revnous"
json.keywords Array(blog.keywords)
json.published_at blog.published_at&.iso8601
json.updated_at blog.updated_at.iso8601
json.url blog_url(blog.slug)
json.canonical_url(blog.canonical_url_override.presence || blog_url(blog.slug))
json.markdown_url blog_url(blog.slug, format: :md)
json.og_image_url(blog.og_image.attached? ? blog.og_image_url : blog.cover_photo_url)
