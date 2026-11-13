# Replaces every case study with the playbooks in db/data/case_studies.yml.
# The earlier records were demo content written to test the site design
# (invented customers and results), so they are deleted, not kept.
class ReplaceDemoCaseStudies < ActiveRecord::Migration[8.0]
  class MigrationCaseStudy < ActiveRecord::Base
    self.table_name = "case_studies"
  end

  DATA_FILE = Rails.root.join("db/data/case_studies.yml")

  def up
    ActiveStorage::Attachment.where(record_type: "CaseStudy").find_each(&:purge)
    execute "DELETE FROM case_studies_products"
    MigrationCaseStudy.delete_all

    MigrationCaseStudy.reset_column_information
    YAML.safe_load_file(DATA_FILE).each do |attrs|
      MigrationCaseStudy.create!(attrs.transform_values { |value| value == "" ? nil : value })
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
