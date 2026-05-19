class Blog < ApplicationRecord
  has_one_attached :image
  belongs_to :author, class_name: "User", foreign_key: "author_id", optional: true
  has_and_belongs_to_many :products

  ALLOWED_TAGS = %w[p br h1 h2 h3 h4 h5 h6 ul ol li strong em a blockquote code pre img figure figcaption table thead tbody tfoot tr th td colgroup col].freeze
  ALLOWED_ATTRIBUTES = %w[href target rel src alt width height colspan rowspan scope].freeze

  validates :title, :body, presence: true
  validates :slug, uniqueness: true, allow_nil: true

  before_validation :generate_slug, on: :create
  before_save :sanitize_body

  scope :published, -> { where("published_at <= ?", Time.current).order(published_at: :desc) }
  scope :featured, -> { where(featured: true) }
  scope :featured_on_home, -> { where(featured_on_home: true) }

  def seo_title
    meta_title.presence || "#{title} - Revnous"
  end

  def seo_description
    meta_description.presence || ActionController::Base.helpers.strip_tags(body).truncate(160)
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

  private

  def generate_slug
    self.slug ||= title.parameterize if title.present?
  end

  def sanitize_body
    return if body.blank?

    sanitizer = Rails::Html::SafeListSanitizer.new
    self.body = sanitizer.sanitize(body, tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)
  end
end
