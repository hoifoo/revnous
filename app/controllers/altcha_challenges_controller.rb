class AltchaChallengesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create ]

  def create
    hmac_key = ENV.fetch("ALTCHA_HMAC_KEY", "default-secret-key-change-in-production")

    Rails.logger.info("ALTCHA Challenge generation START")
    Rails.logger.info("ALTCHA ENV KEY present: #{ENV['ALTCHA_HMAC_KEY'].present?}")
    Rails.logger.info("ALTCHA Current time: #{Time.now.to_i}")

    if hmac_key == "default-secret-key-change-in-production"
      Rails.logger.error("ALTCHA Challenge FAILED: Using default HMAC key!")
      render json: { error: "Server configuration error" }, status: :internal_server_error
      return
    end

    # Increase expiration to 15 minutes to give users more time
    expires_at = (Time.now + 15.minutes).to_i

    options = Altcha::ChallengeOptions.new(
      hmac_key: hmac_key,
      max_number: 100000,
      expires: expires_at
    )

    challenge = Altcha.create_challenge(options)

    Rails.logger.info("ALTCHA Challenge created successfully (expires: #{expires_at})")

    render json: {
      algorithm: challenge.algorithm,
      challenge: challenge.challenge,
      salt: challenge.salt,
      signature: challenge.signature
    }
  rescue => e
    Rails.logger.error("ALTCHA Challenge generation error: #{e.class} - #{e.message}")
    Rails.logger.error("ALTCHA Backtrace: #{e.backtrace.first(5).join("\n")}")
    render json: { error: "Failed to generate challenge" }, status: :internal_server_error
  end
end
