class CreateSpecialOffers < ActiveRecord::Migration[8.0]
  def change
    create_table :special_offers do |t|
      t.string :title, null: false
      t.string :subtitle
      t.text :description
      t.string :terms_text
      t.string :cta_text, default: "Get the offer"
      t.string :cta_url
      t.string :logo_text
      t.boolean :active, default: false, null: false
      t.text :placement_tags

      t.timestamps
    end

    add_index :special_offers, :active
  end
end
