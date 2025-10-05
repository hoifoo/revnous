class CreatePricingPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :pricing_plans do |t|
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2
      t.string :billing_period, default: "mo"
      t.text :description
      t.string :order_limit
      t.string :cta_text, default: "Try Now for Free"
      t.string :cta_url
      t.text :trial_text
      t.boolean :is_popular, default: false, null: false
      t.boolean :shopify_plus_only, default: false, null: false
      t.integer :position, default: 0, null: false
      t.text :features

      t.timestamps
    end

    add_index :pricing_plans, :position
  end
end
