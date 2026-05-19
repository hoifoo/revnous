class AddSpacingToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :spacing, :string, default: "normal", null: false
  end
end
