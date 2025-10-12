class NewsletterSubscriber < ApplicationRecord
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false, message: "is already subscribed" },
                    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email address" }

  before_validation :normalize_email
  before_create :set_subscribed_at

  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end

  def set_subscribed_at
    self.subscribed_at ||= Time.current
  end
end
