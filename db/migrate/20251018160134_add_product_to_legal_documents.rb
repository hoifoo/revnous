class AddProductToLegalDocuments < ActiveRecord::Migration[8.0]
  def change
    add_reference :legal_documents, :product, null: true, foreign_key: true
    add_index :legal_documents, [:product_id, :document_type], name: 'index_legal_docs_on_product_and_type'
  end
end
