class PricingPlan < ApplicationRecord
  belongs_to :product, optional: true

  validates :name, presence: true
  validates :position, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:position) }

  def features_list
    return [] if features.blank?
    JSON.parse(features)
  rescue JSON::ParserError
    []
  end

  def features_list=(value)
    self.features = value.to_json
  end

  def free_plan?
    price.nil? || price.zero?
  end
end
