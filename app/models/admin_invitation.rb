# frozen_string_literal: true

class AdminInvitation < ApplicationRecord
  EXPIRY_HOURS = 72
  STATUSES = %w[pending accepted rejected].freeze

  belongs_to :invited_by, class_name: "User"

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }
  validate :no_pending_invite_for_email, on: :create
  validate :email_not_already_admin, on: :create

  before_create :generate_token
  before_create :set_expiry

  def expired?
    expires_at < Time.current
  end

  def acceptable?
    status == "pending" && !expired?
  end

  def accept!
    update!(status: "accepted")
  end

  def reject!
    update!(status: "rejected")
  end

  private

  def generate_token
    self.token = SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at = EXPIRY_HOURS.hours.from_now
  end

  def no_pending_invite_for_email
    if AdminInvitation.exists?(email: email, status: "pending")
      errors.add(:email, "already has a pending invitation")
    end
  end

  def email_not_already_admin
    if User.exists?(email: email)
      errors.add(:email, "already has an account")
    end
  end
end
