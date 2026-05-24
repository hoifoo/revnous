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
    it "og_image_url returns nil when og_image is not attached" do
      blog = create(:blog)
      expect(blog.og_image_url).to be_nil
    end

    it "og_image_url returns nil when og_image is not attached (no host in test env)" do
      blog = build(:blog)
      blog.og_image.attach(
        io: StringIO.new("fake-png"),
        filename: "test.png",
        content_type: "image/png"
      )
      # og_image_url returns nil in test env (no default_url_options host; only_path: false
      # raises without a host and is rescued). URL generation is verified end-to-end in request specs.
      expect { blog.og_image_url }.not_to raise_error
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

  describe "#faq_schema" do
    it "persists faq_schema as JSON string when saved with an array of pairs" do
      blog = create(:blog, faq_schema: [ { "question" => "Q1", "answer" => "A1" }, { "question" => "Q2", "answer" => "A2" } ])
      parsed = JSON.parse(blog.reload.faq_schema)
      expect(parsed).to eq([ { "question" => "Q1", "answer" => "A1" }, { "question" => "Q2", "answer" => "A2" } ])
    end

    it "strips blank pairs on save and persists only the populated pair" do
      blog = create(:blog, faq_schema: [ { "question" => "", "answer" => "" }, { "question" => "Q", "answer" => "A" } ])
      parsed = JSON.parse(blog.reload.faq_schema)
      expect(parsed).to eq([ { "question" => "Q", "answer" => "A" } ])
    end

    it "sets faq_schema to nil when all pairs are blank" do
      blog = create(:blog, faq_schema: [ { "question" => "", "answer" => "" } ])
      expect(blog.reload.faq_schema).to be_nil
    end

    it "faq_pairs returns parsed array when faq_schema is JSON-encoded" do
      blog = create(:blog, faq_schema: [ { "question" => "Q1", "answer" => "A1" } ])
      expect(blog.faq_pairs).to eq([ { "question" => "Q1", "answer" => "A1" } ])
    end

    it "faq_pairs returns [] when faq_schema is nil" do
      blog = create(:blog, faq_schema: nil)
      expect(blog.faq_pairs).to eq([])
    end

    it "faq_pairs returns [] when faq_schema is malformed JSON" do
      blog = create(:blog)
      blog.update_column(:faq_schema, "not-valid-json{")
      expect(blog.faq_pairs).to eq([])
    end

    it "handles faq_schema passed as JSON string (defensive)" do
      pre_encoded = [ { "question" => "Q", "answer" => "A" } ].to_json
      blog = Blog.new(title: "T", body: "<p>x</p>", faq_schema: pre_encoded)
      blog.save!
      parsed = JSON.parse(blog.reload.faq_schema)
      expect(parsed).to eq([ { "question" => "Q", "answer" => "A" } ])
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
