class SpecialOffer < ApplicationRecord
  has_and_belongs_to_many :products

  validates :title, presence: true

  PLACEMENT_OPTIONS = %w[pricing home services case_studies blogs].freeze

  def placement_tags_list
    return [] if placement_tags.blank?
    JSON.parse(placement_tags)
  rescue JSON::ParserError
    []
  end

  def placement_tags_list=(value)
    self.placement_tags = value.to_json
  end

  def self.for_page(page_name)
    where(active: true).select do |offer|
      offer.placement_tags_list.include?(page_name.to_s)
    end
  end
end
