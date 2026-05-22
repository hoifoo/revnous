require 'rails_helper'

RSpec.describe "Admin::Blogs", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:blog) { create(:blog) }

  before do
    sign_in admin
  end

  describe "PATCH /update keywords" do
    it "persists keywords as an array when submitted as multiple values" do
      patch admin_blog_path(blog), params: {
        blog: { keywords: ["seo", "marketing", "b2b"] }
      }

      expect(response).to redirect_to(admin_blogs_path)
      blog.reload
      expect(blog.keywords).to eq(["seo", "marketing", "b2b"])
    end

    it "clears keywords when submitted as empty array" do
      blog.update!(keywords: ["existing-kw"])
      patch admin_blog_path(blog), params: {
        blog: { keywords: [] }
      }

      expect(response).to redirect_to(admin_blogs_path)
      blog.reload
      expect(blog.keywords).to eq([])
    end

    it "ignores unexpected nested keys — only array of scalars permitted" do
      patch admin_blog_path(blog), params: {
        blog: { keywords: ["valid-kw"] }
      }

      expect(response).to redirect_to(admin_blogs_path)
      blog.reload
      expect(blog.keywords).to eq(["valid-kw"])
    end
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

    it "updates the blog spacing to relaxed" do
      patch admin_blog_path(blog), params: {
        blog: {
          spacing: "relaxed"
        }
      }

      expect(response).to redirect_to(admin_blogs_path)
      blog.reload
      expect(blog.spacing).to eq("relaxed")
    end

    it "updates the author_id and preserves the legacy author text byline" do
      user = create(:user, :admin)
      patch admin_blog_path(blog), params: {
        blog: { author_id: user.id, author: "Legacy Byline" }
      }

      expect(response).to redirect_to(admin_blogs_path)
      blog.reload
      expect(blog.author).to eq(user)
      expect(blog[:author]).to eq("Legacy Byline")
    end
  end
end
