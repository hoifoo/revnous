class CreateBlogs < ActiveRecord::Migration[8.0]
  def change
    create_table :blogs do |t|
      t.string :title
      t.string :author
      t.datetime :published_at
      t.string :category
      t.text :excerpt
      t.text :content
      t.string :slug
      t.boolean :featured

      t.timestamps
    end
  end
end
