class Blog < ApplicationRecord
  has_one_attached :image
  has_and_belongs_to_many :products

  validates :title, :content, presence: true
  validates :slug, uniqueness: true, allow_nil: true

  before_validation :generate_slug, on: :create

  scope :published, -> { where("published_at <= ?", Time.current).order(published_at: :desc) }
  scope :featured, -> { where(featured: true) }
  scope :featured_on_home, -> { where(featured_on_home: true) }

  def seo_title
    meta_title.presence || "#{title} - Revnous"
  end

  def seo_description
    meta_description.presence || ActionController::Base.helpers.strip_tags(content).truncate(160)
  end

  private

  def generate_slug
    self.slug ||= title.parameterize if title.present?
  end
end
