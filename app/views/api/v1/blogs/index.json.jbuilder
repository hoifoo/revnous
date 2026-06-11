json.data @blogs do |blog|
  json.partial! "api/v1/blogs/blog", blog: blog
end

json.meta do
  json.current_page @blogs.current_page
  json.total_pages @blogs.total_pages
  json.total_count @blogs.total_count
end
