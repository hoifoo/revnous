require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
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
