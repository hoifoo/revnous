class AddSeoFieldsToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :keywords, :jsonb, default: [], null: false
    add_column :blogs, :faq_schema, :text
    add_column :blogs, :canonical_url_override, :string
  end
end
