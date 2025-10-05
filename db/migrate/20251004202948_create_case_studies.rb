class CreateCaseStudies < ActiveRecord::Migration[8.0]
  def change
    create_table :case_studies do |t|
      t.string :name
      t.string :industry
      t.string :product_features
      t.boolean :ad_active
      t.string :image_url
      t.text :description
      t.string :conversion_rate
      t.string :revenue_increase
      t.text :challenge
      t.text :solution
      t.text :results

      t.timestamps
    end
  end
end
