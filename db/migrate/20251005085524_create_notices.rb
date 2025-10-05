class CreateNotices < ActiveRecord::Migration[8.0]
  def change
    create_table :notices do |t|
      t.text :message, null: false
      t.string :link_url
      t.string :link_text, default: "→"
      t.string :background_color, default: "pink-purple"
      t.boolean :active, default: false, null: false

      t.timestamps
    end

    add_index :notices, :active
  end
end
