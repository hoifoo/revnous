class CreateJoinTableBlogsProducts < ActiveRecord::Migration[8.0]
  def change
    create_join_table :blogs, :products do |t|
      t.index [ :blog_id, :product_id ]
      t.index [ :product_id, :blog_id ]
    end
  end
end
