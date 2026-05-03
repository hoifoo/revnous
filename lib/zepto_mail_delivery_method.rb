# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "base64"

class ZeptoMailDeliveryMethod
  ENDPOINT = "https://api.zeptomail.eu/v1.1/email"

  attr_reader :settings

  def initialize(settings = {})
    @settings = settings
  end

  def deliver!(mail)
    api_key = ENV["ZEPTOMAIL_API_KEY"]
    raise "ZEPTOMAIL_API_KEY environment variable is not set" if api_key.nil? || api_key.empty?

    payload = build_payload(mail)

    Rails.logger.info("[ZeptoMail] Sending email to #{mail.to&.join(", ")} subject=#{mail.subject.inspect}")
    Rails.logger.info("[ZeptoMail] Payload (without content): #{payload_summary(payload)}")

    uri = URI.parse(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path)
    request["Accept"] = "application/json"
    request["Content-Type"] = "application/json"
    request["Authorization"] = api_key
    request.body = payload.to_json

    Rails.logger.info("[ZeptoMail] Request body size: #{request.body.bytesize} bytes")

    response = http.request(request)

    Rails.logger.info("[ZeptoMail] Response: #{response.code} #{response.message}")
    Rails.logger.info("[ZeptoMail] Response body: #{response.body}")

    unless response.is_a?(Net::HTTPSuccess)
      error_body = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        response.body
      end
      raise "ZeptoMail API error (#{response.code}): #{error_body}"
    end

    Rails.logger.info("[ZeptoMail] Email sent successfully to #{mail.to&.join(", ")}")
    response
  end

  private

  def build_payload(mail)
    payload = {
      from: build_from_address(mail),
      to: mail.to.map { |addr| { email_address: { address: addr } } },
      subject: mail.subject
    }

    bounce_address = ENV["ZEPTOMAIL_BOUNCE_ADDRESS"]
    payload[:bounce_address] = bounce_address if bounce_address && !bounce_address.empty?

    if mail.reply_to&.any?
      payload[:reply_to] = mail.reply_to.map { |addr| { address: addr } }
    end

    if mail.html_part
      payload[:htmlbody] = mail.html_part.decoded
    elsif mail.content_type&.include?("text/html")
      payload[:htmlbody] = mail.body.decoded
    end

    if mail.text_part
      payload[:textbody] = mail.text_part.decoded
    elsif !mail.html_part && !mail.content_type&.include?("text/html")
      payload[:textbody] = mail.body.decoded
    end

    inline_images = extract_inline_images(mail)
    payload[:inline_images] = inline_images if inline_images.any?

    payload
  end

  def build_from_address(mail)
    header = mail[:from]
    address = header.addresses.first
    name = header.display_names.first
    {
      address: address,
      name: name && !name.empty? ? name : address.split("@").first
    }
  end

  def extract_inline_images(mail)
    mail.attachments.select(&:inline?).filter_map do |attachment|
      next if attachment.content_id.nil?

      {
        mime_type: attachment.mime_type,
        content: Base64.strict_encode64(attachment.body.decoded),
        cid: attachment.content_id.gsub(/[<>]/, "")
      }
    end
  end

  def payload_summary(payload)
    summary = payload.reject { |k, _| [:htmlbody, :textbody, :inline_images].include?(k) }
    summary[:htmlbody_size] = payload[:htmlbody]&.bytesize
    summary[:textbody_size] = payload[:textbody]&.bytesize
    summary[:inline_images_count] = payload[:inline_images]&.length || 0
    summary.to_json
  end
end
