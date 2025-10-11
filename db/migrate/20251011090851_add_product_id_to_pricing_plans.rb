class AddProductIdToPricingPlans < ActiveRecord::Migration[8.0]
  def change
    add_reference :pricing_plans, :product, null: true, foreign_key: true
  end
end
