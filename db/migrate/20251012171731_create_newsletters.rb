class CreateNewsletters < ActiveRecord::Migration[8.0]
  def change
    create_table :newsletters do |t|
      t.string :email, null: false
      t.datetime :subscribed_at
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :newsletters, :email, unique: true
    add_index :newsletters, :active
  end
end
