require "test_helper"

class BlogsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get blogs_url
    assert_response :success
  end

  test "should get show" do
    blog = create(:blog)
    get blog_url(id: blog.slug)
    assert_response :success
  end
end
