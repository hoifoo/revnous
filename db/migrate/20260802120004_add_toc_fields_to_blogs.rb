class AddTocFieldsToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :toc_enabled, :boolean, default: false, null: false
    add_column :blogs, :toc_overrides, :jsonb, default: {}, null: false
  end
end
