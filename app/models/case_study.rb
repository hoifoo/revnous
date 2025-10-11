class CaseStudy < ApplicationRecord
  has_one_attached :image
  has_and_belongs_to_many :products

  def display_image
    if image.attached?
      image
    elsif image_url.present?
      image_url
    else
      nil
    end
  end
end
