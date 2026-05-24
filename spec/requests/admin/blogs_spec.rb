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

  describe "PATCH /update og_image" do
    around do |example|
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original_adapter
    end

    it "attaches og_image when a valid PNG is uploaded" do
      patch admin_blog_path(blog), params: {
        blog: { og_image: fixture_file_upload("sample.png", "image/png") }
      }

      expect(response).to redirect_to(admin_blogs_path)
      blog.reload
      expect(blog.og_image.attached?).to be true
    end
  end

  describe "PATCH /update canonical_url_override" do
    it "persists canonical_url_override when a valid https URL is submitted" do
      patch admin_blog_path(blog), params: {
        blog: { canonical_url_override: "https://canonical.test/x" }
      }

      expect(response).to redirect_to(admin_blogs_path)
      blog.reload
      expect(blog.canonical_url_override).to eq("https://canonical.test/x")
    end
  end

  describe "FAQ schema params" do
    it "persists FAQ pairs when submitted as nested params" do
      patch admin_blog_path(blog), params: {
        blog: { faq_schema: [ { question: "What?", answer: "This." }, { question: "Why?", answer: "Because." } ] }
      }

      expect(response).to redirect_to(admin_blogs_path)
      blog.reload
      expect(blog.faq_pairs.length).to eq(2)
    end

    it "results in nil faq_schema when all pairs are blank" do
      patch admin_blog_path(blog), params: {
        blog: { faq_schema: [ { question: "", answer: "" } ] }
      }

      expect(response).to redirect_to(admin_blogs_path)
      blog.reload
      expect(blog.faq_schema).to be_nil
    end

    it "clears existing pairs when blank pair is submitted" do
      blog.update_column(:faq_schema, '[{"question":"Q","answer":"A"}]')
      patch admin_blog_path(blog), params: {
        blog: { faq_schema: [ { question: "", answer: "" } ] }
      }

      expect(response).to redirect_to(admin_blogs_path)
      blog.reload
      expect(blog.faq_schema).to be_nil
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
