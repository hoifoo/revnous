class CreateBetaUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :beta_users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :company
      t.string :website
      t.string :store_link
      t.integer :product_id, null: false
      t.text :message

      t.timestamps
    end

    add_index :beta_users, :email
    add_index :beta_users, :product_id
  end
end
