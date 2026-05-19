require 'rails_helper'

RSpec.describe Blog, type: :model do
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
  end
end
