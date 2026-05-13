class AddBodyToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :body, :text
  end
end
