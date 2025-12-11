class Product < ApplicationRecord
  has_one_attached :logo
  has_one_attached :cover_photo
  has_many :pricing_plans, dependent: :destroy
  has_many :legal_documents, dependent: :destroy
  has_many :beta_users, dependent: :destroy
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
  scope :published, -> { where(published: true) }

  # SEO methods
  def seo_title
    meta_title.presence || "#{name} - Revnous"
  end

  def seo_description
    meta_description.presence || description.presence&.truncate(160) || "Discover #{name}, a powerful tool for Shopify merchants."
  end

  # Helper methods for legal documents
  def privacy_policy
    legal_documents.active.privacy_policies.latest_version.first
  end

  def terms_of_service
    legal_documents.active.terms_of_service.latest_version.first
  end

  def cover_photo_url
    return nil unless cover_photo.attached?

    if Rails.application.routes.default_url_options[:host]
      Rails.application.routes.url_helpers.url_for(cover_photo)
    else
      # Fallback for console/tests
      Rails.application.routes.url_helpers.rails_blob_path(cover_photo, only_path: false)
    end
  rescue StandardError
    nil
  end
end
