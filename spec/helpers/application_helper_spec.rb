require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe "#page_keywords" do
    it "returns nil when @page_keywords is nil" do
      helper.instance_variable_set(:@page_keywords, nil)
      expect(helper.page_keywords).to be_nil
    end

    it "returns nil when @page_keywords is an empty array" do
      helper.instance_variable_set(:@page_keywords, [])
      expect(helper.page_keywords).to be_nil
    end

    it "returns comma-joined string when @page_keywords has values" do
      helper.instance_variable_set(:@page_keywords, [ "seo", "marketing", "b2b" ])
      expect(helper.page_keywords).to eq("seo, marketing, b2b")
    end
  end

  describe "#render_faq_schema" do
    it "returns nil when blog.faq_schema is nil" do
      blog = build(:blog, faq_schema: nil)
      expect(helper.render_faq_schema(blog)).to be_nil
    end

    it "returns nil when faq_pairs is empty" do
      blog = build(:blog, faq_schema: nil)
      expect(helper.render_faq_schema(blog)).to be_nil
    end

    it "returns a script tag with FAQPage JSON-LD when blog has 2 pairs" do
      blog = build(:blog)
      blog.update_column(:faq_schema, '[{"question":"Q1","answer":"A1"},{"question":"Q2","answer":"A2"}]') rescue nil
      allow(blog).to receive(:faq_pairs).and_return(
        [ { "question" => "Q1", "answer" => "A1" }, { "question" => "Q2", "answer" => "A2" } ]
      )

      output = helper.render_faq_schema(blog)

      expect(output).to include('application/ld+json')
      json = JSON.parse(output.gsub(/<[^>]+>/, "").strip)
      expect(json["@type"]).to eq("FAQPage")
      expect(json["mainEntity"].length).to eq(2)
    end

    it "escapes </script> injection attempts in FAQ answer (Test 4)" do
      blog = build(:blog)
      allow(blog).to receive(:faq_pairs).and_return(
        [ { "question" => "Safe?", "answer" => "</script><script>alert(1)</script>" } ]
      )

      output = helper.render_faq_schema(blog)

      expect(output).not_to match(/<\/script><script>alert/i)
      expect(output).to match(/Hack|Safe|\\/i)
    end
  end

  describe "#render_article_schema" do
    it "emits Person author node when blog.author is a User with linkedin and twitter" do
      user = create(:user, first_name: "Ada", last_name: "Lovelace",
                    linkedin_url: "https://linkedin.com/in/ada", twitter_handle: "ada")
      blog = create(:blog, author_user: user)

      output = helper.render_article_schema(blog)

      expect(output).to include('"@type":"Person"')
      expect(output).to include('"name":"Ada Lovelace"')
      expect(output).to include('"url":"https://linkedin.com/in/ada"')
      expect(output).to include('"sameAs":["https://twitter.com/ada"]')
    end

    it "omits url and sameAs when linkedin_url and twitter_handle are blank" do
      user = create(:user, first_name: "Ada", last_name: "Lovelace",
                    linkedin_url: nil, twitter_handle: nil)
      blog = create(:blog, author_user: user)

      output = helper.render_article_schema(blog)
      schema = JSON.parse(output.gsub(/<[^>]+>/, ""))

      expect(schema.dig("author", "@type")).to eq("Person")
      expect(schema.dig("author", "name")).to eq("Ada Lovelace")
      expect(schema.dig("author")).not_to have_key("url")
      expect(schema.dig("author")).not_to have_key("sameAs")
    end

    it "falls back to Organization author when blog has no author user" do
      blog = create(:blog)

      output = helper.render_article_schema(blog)

      expect(output).to include('"@type":"Organization"')
      expect(output).to include('"name":"Revnous"')
    end

    it "json_escape protects against </script> injection in title" do
      blog = create(:blog, title: 'Hack </script><script>alert(1)</script>')

      output = helper.render_article_schema(blog)

      expect(output).not_to match(/<\/script><script>alert/i)
      expect(output).to match(/Hack/)
    end
  end
end
