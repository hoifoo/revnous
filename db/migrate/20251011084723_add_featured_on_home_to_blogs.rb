class AddFeaturedOnHomeToBlogs < ActiveRecord::Migration[8.0]
  def change
    add_column :blogs, :featured_on_home, :boolean, default: false, null: false
    add_index :blogs, :featured_on_home
  end
end
