class InternalEventJob < ApplicationJob
  queue_as :default

  def perform(message)
    Telegram.new.send_message(message)
  rescue StandardError => e
    logger.error("InternalEventJob failed: #{e.message}")
    logger.error(e.backtrace.join("\n"))
  ensure
    logger.info("InternalEventJob completed for message: #{message}")
  end
end
