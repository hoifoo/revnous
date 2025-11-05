require "net/http"
require "uri"
require "json"

class Telegram
  def initialize
    @api_key = ENV.fetch("TELEGRAM_API_TOKEN")
    @target_chat_id = ENV.fetch("TELEGRAM_CHAT_ID")
  end

  def get_updates
    uri = URI("https://api.telegram.org/bot#{@api_key}/getUpdates")
    response = Net::HTTP.get(uri)
    JSON.parse(response)
  end

  def send_message(message)
    uri = URI("https://api.telegram.org/bot#{@api_key}/sendMessage")
    params = {
      "chat_id" => @target_chat_id,
      "text" => message,
      "parse_mode" => "HTML"
    }
    Net::HTTP.post_form(uri, params)
  end
end
