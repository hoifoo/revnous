class BetaUser < ApplicationRecord
  belongs_to :product

  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { scope: :product_id, message: "has already signed up for beta testing for this product" }
  validates :product_id, presence: true
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true
  validates :store_link, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  scope :recent, -> { order(created_at: :desc) }
end
