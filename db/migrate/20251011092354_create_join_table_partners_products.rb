class CreateJoinTablePartnersProducts < ActiveRecord::Migration[8.0]
  def change
    create_join_table :partners, :products do |t|
      t.index [ :partner_id, :product_id ]
      t.index [ :product_id, :partner_id ]
    end
  end
end
