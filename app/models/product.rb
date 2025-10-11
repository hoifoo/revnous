class Product < ApplicationRecord
  has_one_attached :logo
  has_one_attached :cover_photo
  has_many :pricing_plans, dependent: :destroy
  has_and_belongs_to_many :blogs
  has_and_belongs_to_many :case_studies
  has_and_belongs_to_many :special_offers
  has_and_belongs_to_many :partners

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :featured, -> { where(featured: true) }
  scope :featured_on_home, -> { where(featured_on_home: true) }
  scope :with_cover_photo, -> { joins(:cover_photo_attachment) }
  scope :ordered, -> { order(position: :asc, created_at: :desc) }
end
