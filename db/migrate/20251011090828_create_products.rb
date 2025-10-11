class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :product_type
      t.string :url
      t.text :short_description
      t.text :description
      t.boolean :featured, default: false, null: false
      t.boolean :featured_on_home, default: false, null: false
      t.boolean :active, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :products, :featured
    add_index :products, :featured_on_home
    add_index :products, :active
    add_index :products, :position
  end
end
