class BetaUsersController < ApplicationController
  def index
    # Show the beta signup form page
    @products = Product.active.ordered

    # Check if this is a product-scoped route
    if params[:product_slug].present?
      @product = Product.find_by(id: params[:product_slug]) || Product.find_by("LOWER(name) = ?", params[:product_slug].downcase.gsub('-', ' '))
    elsif params[:product_id].present?
      @product = Product.find_by(id: params[:product_id])
    end
  end

  def create
    # Verify ALTCHA payload first
    unless verify_altcha_payload
      redirect_to beta_signup_path, alert: "CAPTCHA verification failed. Please try again."
      return
    end

    @beta_user_params = beta_user_params

    # Create the beta user
    @beta_user = BetaUser.new(@beta_user_params)

    if @beta_user.save
      # Format message for Telegram
      telegram_message = format_telegram_message(@beta_user)

      # Send to Telegram asynchronously
      InternalEventJob.perform_later(telegram_message)

      redirect_to root_path, notice: "Thank you for signing up for beta access! We'll get back to you soon at #{@beta_user.email}."
    else
      @products = Product.active.ordered
      @product = Product.find_by(id: @beta_user_params[:product_id])
      flash.now[:alert] = @beta_user.errors.full_messages.join(", ")
      render :index, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error("Beta user signup error: #{e.message}")
    redirect_to beta_signup_path, alert: "Sorry, there was an error processing your request. Please try again or email us directly at contact@revnous.com."
  end

  private

  def beta_user_params
    params.require(:beta_user).permit(:name, :email, :company, :website, :store_link, :product_id, :message)
  end

  def verify_altcha_payload
    altcha_payload = params[:altcha]

    Rails.logger.info("ALTCHA Verification START")
    Rails.logger.info("ALTCHA Payload received: #{altcha_payload.inspect}")
    Rails.logger.info("ALTCHA ENV KEY present: #{ENV['ALTCHA_HMAC_KEY'].present?}")
    Rails.logger.info("ALTCHA Current time: #{Time.now.to_i}")

    if altcha_payload.blank?
      Rails.logger.error("ALTCHA FAILED: Payload is blank")
      return false
    end

    begin
      # Decode Base64 payload first, then parse JSON
      payload_data = if altcha_payload.is_a?(String)
        begin
          # Try to decode as Base64 first
          decoded = Base64.decode64(altcha_payload)
          Rails.logger.info("ALTCHA Decoded payload: #{decoded}")
          JSON.parse(decoded)
        rescue => e
          # If Base64 decode fails, try direct JSON parse
          Rails.logger.info("ALTCHA Direct JSON parse (not Base64): #{e.message}")
          JSON.parse(altcha_payload)
        end
      else
        altcha_payload
      end

      Rails.logger.info("ALTCHA Parsed payload: #{payload_data.inspect}")

      hmac_key = ENV.fetch('ALTCHA_HMAC_KEY', 'default-secret-key-change-in-production')

      if hmac_key == 'default-secret-key-change-in-production'
        Rails.logger.error("ALTCHA FAILED: Using default HMAC key - environment variable not set!")
        return false
      end

      # Convert string keys to symbols if needed
      payload_hash = payload_data.symbolize_keys if payload_data.respond_to?(:symbolize_keys)
      payload_hash ||= payload_data.transform_keys(&:to_sym) if payload_data.is_a?(Hash)

      Rails.logger.info("ALTCHA Payload hash: #{payload_hash.inspect}")
      Rails.logger.info("ALTCHA Challenge expires: #{payload_hash[:expires]} (current: #{Time.now.to_i})")

      # Check if challenge has expired
      if payload_hash[:expires] && payload_hash[:expires] < Time.now.to_i
        Rails.logger.error("ALTCHA FAILED: Challenge expired (expires: #{payload_hash[:expires]}, now: #{Time.now.to_i})")
        return false
      end

      # Verify the solution
      result = Altcha.verify_solution(payload_hash, hmac_key, true)
      Rails.logger.info("ALTCHA Verification result: #{result}")

      unless result
        Rails.logger.error("ALTCHA FAILED: verify_solution returned false")
      end

      result
    rescue JSON::ParserError => e
      Rails.logger.error("ALTCHA JSON parse error: #{e.message}")
      Rails.logger.error("ALTCHA Raw payload: #{altcha_payload}")
      false
    rescue => e
      Rails.logger.error("ALTCHA verification error: #{e.class} - #{e.message}")
      Rails.logger.error("ALTCHA Backtrace: #{e.backtrace.first(5).join("\n")}")
      false
    end
  end

  def format_telegram_message(beta_user)
    product_name = beta_user.product&.name || "Unknown Product"

    <<~MESSAGE
      <b>🚀 New Beta User Signup</b>

      <b>Name:</b> #{beta_user.name}
      <b>Email:</b> #{beta_user.email}
      <b>Company:</b> #{beta_user.company.present? ? beta_user.company : 'Not provided'}
      <b>Product:</b> #{product_name}
      <b>Website:</b> #{beta_user.website.present? ? beta_user.website : 'Not provided'}
      <b>Store Link:</b> #{beta_user.store_link.present? ? beta_user.store_link : 'Not provided'}

      <b>Message:</b>
      #{beta_user.message.present? ? beta_user.message : 'No message provided'}

      ---
      Submitted at: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}
    MESSAGE
  end
end
