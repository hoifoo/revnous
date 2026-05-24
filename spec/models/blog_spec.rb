require 'rails_helper'

RSpec.describe Blog, type: :model do
  describe "#generate_slug" do
    it "auto-generates slug from title on create" do
      blog = create(:blog, title: "Hello World", slug: nil)
      expect(blog.slug).to eq("hello-world")
    end

    it "auto-generates slug when form submits blank string" do
      blog = create(:blog, title: "Hello World", slug: "")
      expect(blog.slug).to eq("hello-world")
    end

    it "does not overwrite an explicitly provided slug" do
      blog = create(:blog, title: "Hello World", slug: "custom-slug")
      expect(blog.slug).to eq("custom-slug")
    end
  end

  describe "#keywords" do
    it "returns [] by default after save (jsonb default)" do
      blog = create(:blog)
      expect(blog.reload.keywords).to eq([])
    end

    it "persists keywords as an Array and round-trips correctly" do
      blog = create(:blog, keywords: ["seo", "marketing"])
      expect(blog.reload.keywords).to eq(["seo", "marketing"])
    end

    it "returns '' when keywords is nil" do
      blog = build(:blog)
      blog.keywords = nil
      expect(blog.keywords_list).to eq("")
    end

    it "returns '' when keywords is []" do
      blog = build(:blog, keywords: [])
      expect(blog.keywords_list).to eq("")
    end

    it "returns comma-joined string when keywords is present" do
      blog = build(:blog, keywords: ["seo", "marketing", "b2b"])
      expect(blog.keywords_list).to eq("seo, marketing, b2b")
    end
  end

  describe "#canonical_url_override validation" do
    it "is valid when canonical_url_override is nil" do
      blog = build(:blog, canonical_url_override: nil)
      expect(blog).to be_valid
    end

    it "is valid when canonical_url_override is blank string" do
      blog = build(:blog, canonical_url_override: "")
      expect(blog).to be_valid
    end

    it "is valid with an https URL" do
      blog = build(:blog, canonical_url_override: "https://example.com/post")
      expect(blog).to be_valid
    end

    it "is valid with an http URL" do
      blog = build(:blog, canonical_url_override: "http://example.com")
      expect(blog).to be_valid
    end

    it "is invalid with a javascript: scheme" do
      blog = build(:blog, canonical_url_override: "javascript:alert(1)")
      expect(blog).not_to be_valid
      expect(blog.errors[:canonical_url_override]).to include("must be a valid http or https URL")
    end

    it "is invalid with a non-URL string" do
      blog = build(:blog, canonical_url_override: "not a url")
      expect(blog).not_to be_valid
    end

    it "persists canonical_url_override when present" do
      blog = create(:blog, canonical_url_override: "https://canonical.test/post")
      expect(blog.reload.canonical_url_override).to eq("https://canonical.test/post")
    end
  end

  describe "#og_image" do
    around do |example|
      # Use :test adapter to avoid SolidQueue DB tables being needed during attach
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original_adapter
    end

    it "og_image_url returns nil when og_image is not attached" do
      blog = create(:blog)
      expect(blog.og_image_url).to be_nil
    end

    it "og_image_url returns a URL string when og_image is attached" do
      blog = create(:blog)
      blog.og_image.attach(
        io: StringIO.new("fake-png"),
        filename: "test.png",
        content_type: "image/png"
      )
      blog.save!
      # Set host so rails_blob_path(only_path: false) can build a full URL
      Rails.application.routes.default_url_options[:host] = "www.example.com"
      expect(blog.og_image_url).to be_a(String)
      expect(blog.og_image_url).to be_present
    ensure
      Rails.application.routes.default_url_options.delete(:host)
    end

    it "is invalid when og_image has content_type application/pdf (non-image rejected)" do
      blog = build(:blog)
      blog.og_image.attach(
        io: StringIO.new("fake-pdf"),
        filename: "test.pdf",
        content_type: "application/pdf"
      )
      expect(blog).not_to be_valid
      expect(blog.errors[:og_image]).to be_present
    end

    it "is valid when og_image has content_type image/png" do
      blog = build(:blog)
      blog.og_image.attach(
        io: StringIO.new("fake-png"),
        filename: "test.png",
        content_type: "image/png"
      )
      expect(blog).to be_valid
    end

    it "is invalid when og_image has content_type image/svg+xml (SVG rejected to prevent stored-XSS)" do
      blog = build(:blog)
      blog.og_image.attach(
        io: StringIO.new("<svg><script>alert(1)</script></svg>"),
        filename: "evil.svg",
        content_type: "image/svg+xml"
      )
      expect(blog).not_to be_valid
      expect(blog.errors[:og_image]).to be_present
    end

    it "purges og_image attachment when content_type is invalid" do
      blog = build(:blog)
      blog.og_image.attach(
        io: StringIO.new("fake-pdf"),
        filename: "test.pdf",
        content_type: "application/pdf"
      )
      blog.valid?
      expect(blog.og_image.attached?).to be false
    end
  end

  describe "#sanitize_body" do
    it "preserves table markup and table-specific attributes" do
      body = '<table><thead><tr><th>H</th></tr></thead><tbody><tr><td colspan="2" scope="col">x</td></tr></tbody></table>'
      blog = build(:blog, body: body)
      blog.save!
      expect(blog.body).to include('<table>')
      expect(blog.body).to include('<thead>')
      expect(blog.body).to include('<tbody>')
      expect(blog.body).to include('<th>')
      expect(blog.body).to include('<td')
      expect(blog.body).to include('colspan="2"')
      expect(blog.body).to include('scope="col"')
    end

    it "strips disallowed attributes on table tags" do
      body = '<table onclick="alert(1)"><tr><td>x</td></tr></table>'
      blog = build(:blog, body: body)
      blog.save!
      expect(blog.body).not_to include('onclick')
      expect(blog.body).to include('<table>')
      expect(blog.body).to include('<td>x</td>')
    end

    it "preserves img tags with src, alt, and width attributes" do
      body = '<p><img src="/rails/active_storage/blobs/redirect/xyz/photo.jpg" alt="A photo" width="480"></p>'
      blog = build(:blog, body: body)
      blog.save!
      expect(blog.body).to include('<img')
      expect(blog.body).to include('src="/rails/active_storage/blobs/redirect/xyz/photo.jpg"')
      expect(blog.body).to include('alt="A photo"')
      expect(blog.body).to include('width="480"')
    end

    it "strips onerror and other event-handler attributes on img tags" do
      body = '<img src="x" onerror="alert(1)" alt="x">'
      blog = build(:blog, body: body)
      blog.save!
      expect(blog.body).not_to include('onerror')
      expect(blog.body).to include('<img')
      expect(blog.body).to include('src="x"')
      expect(blog.body).to include('alt="x"')
    end
  end
end
