class CaseStudy < ApplicationRecord
  has_one_attached :image
  has_and_belongs_to_many :products

  scope :published, -> { where(published: true) }

  def display_image
    if image.attached?
      image
    elsif image_url.present?
      image_url
    else
      nil
    end
  end

  def key_results_list
    key_results.to_s.lines.map(&:strip).reject(&:blank?)
  end

  def highlights
    [
      [ conversion_rate, primary_stat_label ],
      [ revenue_increase, secondary_stat_label ],
      [ product_features, "Feature used" ]
    ].select { |value, _| value.present? }
  end
end
