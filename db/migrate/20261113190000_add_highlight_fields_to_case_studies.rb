class AddHighlightFieldsToCaseStudies < ActiveRecord::Migration[8.0]
  def change
    add_column :case_studies, :primary_stat_label, :string
    add_column :case_studies, :secondary_stat_label, :string
    add_column :case_studies, :key_results, :text
    add_column :case_studies, :quote, :text
    add_column :case_studies, :quote_attribution, :string
  end
end
