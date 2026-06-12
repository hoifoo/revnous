module AnalyticsHelper
  ANALYTICS_PROVIDERS_PATH = Rails.root.join("config/analytics_providers.json")

  # Required credential key per provider, used to gate dormant providers.
  REQUIRED_CREDENTIALS = {
    "google_analytics" => %w[measurement_id],
    "mixpanel" => %w[token]
  }.freeze

  # Parses config/analytics_providers.json and returns the providers array.
  # Fails safe: returns [] and logs on missing/malformed JSON so the consent
  # banner can still render the Essential category.
  def analytics_providers
    if Rails.env.production?
      Rails.cache.fetch("analytics_providers", expires_in: 1.hour) { load_analytics_providers }
    else
      load_analytics_providers
    end
  end

  # Providers that are active AND have their required credential present.
  # This is the gate that keeps Mixpanel dormant until both flip.
  def enabled_analytics_providers
    analytics_providers.select do |provider|
      provider["active"] == true && required_credential_present?(provider)
    end
  end

  # Browser-needed subset of enabled providers, serialized for the
  # cookie-consent mount div's data-providers attribute. Only public
  # client-side tokens are included here.
  def analytics_consent_config_json
    enabled_analytics_providers.map do |provider|
      {
        "key" => provider["key"],
        "name" => provider["name"],
        "category" => provider["category"],
        "description" => provider["description"],
        "config" => provider["config"],
        "cookies" => Array(provider["cookies"]).map do |cookie|
          {
            "name" => cookie["name"],
            "purpose" => cookie["purpose"],
            "retention" => cookie["retention"]
          }
        end
      }
    end.to_json
  end

  private

  def load_analytics_providers
    data = JSON.parse(File.read(ANALYTICS_PROVIDERS_PATH))
    Array(data["providers"])
  rescue JSON::ParserError, Errno::ENOENT => e
    Rails.logger.error("Failed to load analytics providers config: #{e.message}")
    []
  end

  def required_credential_present?(provider)
    required_keys = REQUIRED_CREDENTIALS[provider["key"]] || []
    config = provider["config"] || {}
    required_keys.all? { |key| config[key].present? }
  end
end
