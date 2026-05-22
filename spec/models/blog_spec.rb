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
