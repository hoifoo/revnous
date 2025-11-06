class CreateJoinTableSpecialOffersProducts < ActiveRecord::Migration[8.0]
  def change
    create_join_table :special_offers, :products do |t|
      t.index [ :special_offer_id, :product_id ]
      t.index [ :product_id, :special_offer_id ]
    end
  end
end
