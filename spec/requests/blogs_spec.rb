require 'rails_helper'

RSpec.describe "Blogs", type: :request do
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
