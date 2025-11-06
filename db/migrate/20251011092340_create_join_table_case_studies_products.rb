class CreateJoinTableCaseStudiesProducts < ActiveRecord::Migration[8.0]
  def change
    create_join_table :case_studies, :products do |t|
      t.index [ :case_study_id, :product_id ]
      t.index [ :product_id, :case_study_id ]
    end
  end
end
