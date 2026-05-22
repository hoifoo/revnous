require 'rails_helper'

RSpec.describe "Blogs", type: :request do
  describe "GET /blog/:id canonical URL" do
    it "uses canonical_url_override when present" do
      blog = create(:blog, slug: "canonical-override-test",
                    canonical_url_override: "https://canonical.test/post",
                    published_at: 1.day.ago)

      get blog_path(blog.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<link rel="canonical" href="https://canonical.test/post">')
    end

    it "falls back to blog_url when canonical_url_override is nil" do
      blog = create(:blog, slug: "no-canonical-override",
                    canonical_url_override: nil,
                    published_at: 1.day.ago)

      get blog_path(blog.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<link rel="canonical" href="http://www.example.com/blog/no-canonical-override">')
    end

    it "falls back to blog_url when canonical_url_override is blank string" do
      blog = create(:blog, slug: "blank-canonical-override",
                    canonical_url_override: "",
                    published_at: 1.day.ago)

      get blog_path(blog.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<link rel="canonical" href="http://www.example.com/blog/blank-canonical-override">')
    end
  end

  describe "GET /blog/:id (show)" do
    it "renders keywords meta tag when blog has keywords" do
      blog = create(:blog, slug: "keywords-test", keywords: ["seo", "marketing"],
                    published_at: 1.day.ago)

      get blog_path(blog.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<meta name="keywords" content="seo, marketing">')
    end

    it "omits keywords meta tag entirely when blog has no keywords" do
      blog = create(:blog, slug: "no-keywords-test", keywords: [],
                    published_at: 1.day.ago)

      get blog_path(blog.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body.scan('<meta name="keywords"').length).to eq(0)
    end
  end
end
