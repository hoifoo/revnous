class CreateSeoMetadata < ActiveRecord::Migration[8.0]
  def change
    create_table :seo_metadata do |t|
      t.string :page_identifier
      t.string :page_title
      t.text :meta_description

      t.timestamps
    end
    add_index :seo_metadata, :page_identifier, unique: true
  end
end
