class Blog < ApplicationRecord
  has_one_attached :image
  has_one_attached :og_image
  belongs_to :author, class_name: "User", foreign_key: "author_id", optional: true
  has_and_belongs_to_many :products

  ALLOWED_TAGS = %w[p br h1 h2 h3 h4 h5 h6 ul ol li strong em a blockquote code pre img figure figcaption table thead tbody tfoot tr th td colgroup col].freeze
  ALLOWED_ATTRIBUTES = %w[href target rel src alt width height colspan rowspan scope].freeze

  validates :title, :body, presence: true
  validates :slug, uniqueness: true, allow_nil: true
  validates :canonical_url_override, format: {
    with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    allow_blank: true,
    message: "must be a valid http or https URL"
  }
  validate :validate_og_image_content_type

  before_validation :generate_slug, on: :create
  before_save :sanitize_body
  before_save :normalize_keywords
  before_save :parse_faq_schema

  scope :published, -> { where("published_at <= ?", Time.current).order(published_at: :desc) }
  scope :featured, -> { where(featured: true) }
  scope :featured_on_home, -> { where(featured_on_home: true) }

  def seo_title
    meta_title.presence || "#{title} - Revnous"
  end

  def seo_description
    meta_description.presence || ActionController::Base.helpers.strip_tags(body).truncate(160)
  end

  def keywords_list
    Array(keywords).join(", ")
  end

  def cover_photo_url
    return nil unless image.attached?

    if Rails.application.routes.default_url_options[:host]
      Rails.application.routes.url_helpers.url_for(image)
    else
      # Fallback for console/tests
      Rails.application.routes.url_helpers.rails_blob_path(image, only_path: false)
    end
  rescue StandardError
    nil
  end

  def faq_schema=(value)
    # When assigned an Array (e.g. from tests or ActionController::Parameters),
    # JSON-encode it immediately so the text column stores valid JSON, not Ruby inspect.
    if value.is_a?(Array) || value.is_a?(ActionController::Parameters)
      super(Array(value).to_json)
    else
      super(value)
    end
  end

  def faq_pairs
    return [] if faq_schema.blank?

    parsed = JSON.parse(faq_schema)
    parsed.is_a?(Array) ? parsed : []
  rescue JSON::ParserError
    []
  end

  def og_image_url
    return nil unless og_image.attached?

    if Rails.application.routes.default_url_options[:host]
      Rails.application.routes.url_helpers.url_for(og_image)
    else
      # Fallback for console/tests
      Rails.application.routes.url_helpers.rails_blob_path(og_image, only_path: false)
    end
  rescue StandardError
    nil
  end

  private

  def generate_slug
    self.slug = title.parameterize if slug.blank? && title.present?
  end

  def validate_og_image_content_type
    return unless og_image.attached?

    allowed_types = %w[image/png image/jpeg image/jpg image/gif image/webp]
    unless allowed_types.include?(og_image.blob.content_type.to_s.downcase)
      errors.add(:og_image, "must be a PNG, JPEG, GIF, or WebP image")
      og_image.purge
    end
  end

  def normalize_keywords
    self.keywords = Array(keywords).reject(&:blank?)
  end

  def parse_faq_schema
    return if faq_schema.blank?

    pairs = if faq_schema.is_a?(String)
      begin
        JSON.parse(faq_schema)
      rescue JSON::ParserError
        self.faq_schema = nil
        return
      end
    else
      Array(faq_schema)
    end

    cleaned = pairs.map do |entry|
      { "question" => entry["question"].to_s.strip, "answer" => entry["answer"].to_s.strip }
    end.reject { |p| p["question"].blank? && p["answer"].blank? }

    self.faq_schema = cleaned.empty? ? nil : cleaned.to_json
  end

  def sanitize_body
    return if body.blank?

    sanitizer = Rails::Html::SafeListSanitizer.new
    self.body = sanitizer.sanitize(body, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
  end
end
