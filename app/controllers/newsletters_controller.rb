class NewslettersController < ApplicationController
  def create
    @newsletter = NewsletterSubscriber.new(newsletter_params)

    if @newsletter.save
      # Send notification to Telegram
      send_telegram_notification(@newsletter.email)

      redirect_to root_path, notice: "Thank you for subscribing! Check your inbox to confirm your subscription."
    else
      error_message = if @newsletter.errors[:email].include?("is already subscribed")
        "This email is already subscribed to our newsletter."
      else
        "Please enter a valid email address."
      end

      redirect_to root_path, alert: error_message
    end
  rescue => e
    Rails.logger.error("Newsletter subscription error: #{e.message}")
    redirect_to root_path, alert: "Sorry, there was an error. Please try again later."
  end

  private

  def newsletter_params
    params.require(:newsletter).permit(:email)
  end

  def send_telegram_notification(email)
    message = <<~MESSAGE
      <b>📧 New Newsletter Subscription</b>

      <b>Email:</b> #{email}
      <b>Subscribed at:</b> #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}

      Total subscribers: #{NewsletterSubscriber.active.count}
    MESSAGE

    InternalEventJob.perform_later(message)
  end
end
