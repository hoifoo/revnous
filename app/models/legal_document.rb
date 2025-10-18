class LegalDocument < ApplicationRecord
  # Associations
  belongs_to :product, optional: true

  # Constants for document types
  DOCUMENT_TYPES = %w[privacy_policy terms_of_service].freeze

  # Validations
  validates :title, presence: true
  validates :slug, presence: true, uniqueness: { scope: :product_id }
  validates :document_type, presence: true, inclusion: { in: DOCUMENT_TYPES }
  validates :content, presence: true
  validates :version, presence: true

  # Callbacks
  before_validation :generate_slug, if: -> { slug.blank? && title.present? }
  before_validation :set_default_effective_date, if: -> { effective_date.blank? }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :privacy_policies, -> { where(document_type: "privacy_policy") }
  scope :terms_of_service, -> { where(document_type: "terms_of_service") }
  scope :global, -> { where(product_id: nil) }
  scope :for_product, ->(product) { where(product: product) }
  scope :ordered, -> { order(effective_date: :desc, created_at: :desc) }
  scope :latest_version, -> { ordered.limit(1) }

  # Class methods
  def self.current_privacy_policy(product = nil)
    scope = active.privacy_policies
    scope = product ? scope.for_product(product) : scope.global
    scope.latest_version.first
  end

  def self.current_terms_of_service(product = nil)
    scope = active.terms_of_service
    scope = product ? scope.for_product(product) : scope.global
    scope.latest_version.first
  end

  # Instance methods
  def privacy_policy?
    document_type == "privacy_policy"
  end

  def terms_of_service?
    document_type == "terms_of_service"
  end

  def global?
    product_id.nil?
  end

  def human_document_type
    document_type.humanize
  end

  def scoped_name
    if product
      "#{product.name} - #{human_document_type}"
    else
      "Global #{human_document_type}"
    end
  end

  private

  def generate_slug
    base_slug = title.parameterize
    self.slug = product_id ? "#{product_id}-#{base_slug}" : base_slug
  end

  def set_default_effective_date
    self.effective_date = Date.today
  end
end
