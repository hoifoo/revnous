class AltchaChallengesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]

  def create
    hmac_key = ENV.fetch('ALTCHA_HMAC_KEY', 'default-secret-key-change-in-production')

    options = Altcha::ChallengeOptions.new(
      hmac_key: hmac_key,
      max_number: 100000,
      expires: (Time.now + 5.minutes).to_i
    )

    challenge = Altcha.create_challenge(options)

    render json: {
      algorithm: challenge.algorithm,
      challenge: challenge.challenge,
      salt: challenge.salt,
      signature: challenge.signature
    }
  end
end
