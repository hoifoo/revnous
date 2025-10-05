class CreateTrustedBrands < ActiveRecord::Migration[8.0]
  def change
    create_table :trusted_brands do |t|
      t.string :name, null: false
      t.string :font_style, default: "bold"
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :trusted_brands, :position
  end
end
