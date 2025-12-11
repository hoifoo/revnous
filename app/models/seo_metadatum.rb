class SeoMetadatum < ApplicationRecord
  validates :page_identifier, presence: true, uniqueness: true
  validates :page_title, presence: true
end
