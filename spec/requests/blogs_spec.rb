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

  describe "GET /blog/:id og:image fallback chain" do
    around do |example|
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      # Set host so that rails_blob_path(only_path: false) can build full URLs via og_image_url / cover_photo_url
      Rails.application.routes.default_url_options[:host] = "www.example.com"
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original_adapter
      Rails.application.routes.default_url_options.delete(:host)
    end

    it "uses og_image URL in og:image meta tag when og_image is attached (not cover photo)" do
      blog = create(:blog, slug: "og-image-test", published_at: 1.day.ago)
      # Attach both og_image and cover photo — og_image must win
      blog.og_image.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
        filename: "og-sample.png",
        content_type: "image/png"
      )
      blog.image.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
        filename: "cover-sample.png",
        content_type: "image/png"
      )
      blog.save!
      blog.reload

      get blog_path(blog.slug)

      expect(response).to have_http_status(:ok)
      og_url = blog.og_image_url
      cover_url = blog.cover_photo_url
      expect(og_url).to be_present
      expect(cover_url).to be_present
      # og:image must point to og_image blob, not cover photo blob
      og_blob_key = blog.og_image.blob.key
      cover_blob_key = blog.image.blob.key
      expect(og_blob_key).not_to eq(cover_blob_key)
      expect(response.body).to include(og_url)
    end

    it "uses cover_photo_url in og:image meta tag when no og_image but cover photo is attached" do
      blog = create(:blog, slug: "cover-og-fallback-test", published_at: 1.day.ago)
      blog.image.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/sample.png")),
        filename: "sample.png",
        content_type: "image/png"
      )
      blog.save!
      blog.reload

      get blog_path(blog.slug)

      expect(response).to have_http_status(:ok)
      cover_url = blog.cover_photo_url
      expect(cover_url).to be_present
      expect(response.body).to include(cover_url)
    end

    it "falls back to /logo.png in og:image meta tag when neither og_image nor cover photo is attached" do
      blog = create(:blog, slug: "logo-og-fallback-test", published_at: 1.day.ago)

      get blog_path(blog.slug)

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/og:image.*logo\.png|logo\.png.*og:image/m)
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
