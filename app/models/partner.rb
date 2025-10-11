class Partner < ApplicationRecord
  has_one_attached :logo
  has_and_belongs_to_many :products

  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, created_at: :desc) }
end
