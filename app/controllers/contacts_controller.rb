class ContactsController < ApplicationController
  def create
    # Verify ALTCHA payload first
    unless verify_altcha_payload
      redirect_to root_path, alert: "CAPTCHA verification failed. Please try again."
      return
    end

    @contact_params = contact_params

    # Format message for Telegram
    telegram_message = format_telegram_message(@contact_params)

    # Send to Telegram asynchronously
    InternalEventJob.perform_later(telegram_message)

    redirect_to root_path, notice: "Thank you for contacting us! We'll get back to you soon at #{@contact_params[:email]}."
  rescue => e
    Rails.logger.error("Contact form error: #{e.message}")
    redirect_to root_path, alert: "Sorry, there was an error sending your message. Please try again or email us directly at contact@revnous.com."
  end

  private

  def contact_params
    params.require(:contact).permit(:name, :email, :company, :subject, :message)
  end

  def verify_altcha_payload
    altcha_payload = params[:altcha]

    Rails.logger.info("ALTCHA Payload received: #{altcha_payload.inspect}")

    return false if altcha_payload.blank?

    begin
      # Parse the JSON payload
      payload_data = if altcha_payload.is_a?(String)
        JSON.parse(altcha_payload)
      else
        altcha_payload
      end

      Rails.logger.info("ALTCHA Parsed payload: #{payload_data.inspect}")

      hmac_key = ENV.fetch('ALTCHA_HMAC_KEY', 'default-secret-key-change-in-production')

      # Convert string keys to symbols if needed
      payload_hash = payload_data.symbolize_keys if payload_data.respond_to?(:symbolize_keys)
      payload_hash ||= payload_data.transform_keys(&:to_sym) if payload_data.is_a?(Hash)

      Rails.logger.info("ALTCHA Payload hash: #{payload_hash.inspect}")

      # Verify the solution
      result = Altcha.verify_solution(payload_hash, hmac_key, true)
      Rails.logger.info("ALTCHA Verification result: #{result}")

      result
    rescue JSON::ParserError => e
      Rails.logger.error("ALTCHA JSON parse error: #{e.message}")
      false
    rescue => e
      Rails.logger.error("ALTCHA verification error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      false
    end
  end

  def format_telegram_message(params)
    <<~MESSAGE
      <b>🔔 New Contact Form Submission</b>

      <b>Name:</b> #{params[:name]}
      <b>Email:</b> #{params[:email]}
      <b>Company:</b> #{params[:company].present? ? params[:company] : 'Not provided'}
      <b>Subject:</b> #{params[:subject]}

      <b>Message:</b>
      #{params[:message]}

      ---
      Submitted at: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}
    MESSAGE
  end
end
