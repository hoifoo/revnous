require 'rails_helper'

RSpec.describe "Admin::Blogs", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:blog) { create(:blog) }

  before do
    sign_in admin
  end

  describe "PATCH /update" do
    it "updates the blog meta fields" do
      patch admin_blog_path(blog), params: {
        blog: {
          meta_title: "New SEO Title",
          meta_description: "New SEO Description"
        }
      }

      expect(response).to redirect_to(admin_blogs_path)
      blog.reload
      expect(blog.meta_title).to eq("New SEO Title")
      expect(blog.meta_description).to eq("New SEO Description")
    end
  end
end
