class CreateLegalDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :legal_documents do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :content
      t.string :document_type, null: false
      t.boolean :active, default: true, null: false
      t.string :version, default: "1.0"
      t.date :effective_date

      t.timestamps
    end

    add_index :legal_documents, :slug, unique: true
    add_index :legal_documents, :document_type
    add_index :legal_documents, :active
  end
end
