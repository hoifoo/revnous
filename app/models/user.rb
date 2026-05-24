class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one_attached :avatar
  has_many :authored_blogs, class_name: "Blog", foreign_key: "author_id", dependent: :nullify

  before_validation :normalize_twitter_handle

  validates :linkedin_url, format: {
    with: URI::DEFAULT_PARSER.make_regexp(%w[http https]),
    allow_blank: true,
    message: "must be a valid http or https URL"
  }

  def full_name
    [ first_name, last_name ].compact_blank.join(" ").presence || email
  end

  def initials
    [ first_name&.first, last_name&.first ].compact.join.upcase.presence || "?"
  end

  private

  def normalize_twitter_handle
    self.twitter_handle = twitter_handle.to_s.strip.delete_prefix("@").presence
  end
end
