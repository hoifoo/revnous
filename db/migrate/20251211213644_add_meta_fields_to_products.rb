class AddMetaFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :meta_title, :string
    add_column :products, :meta_description, :text
  end
end
