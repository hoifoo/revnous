RSpec.configure do |config|
  # Include Devise test helpers for request specs
  config.include Devise::Test::IntegrationHelpers, type: :request

  # Ensure Warden is configured and routes are available
  config.before(:suite) do
    # Ensure routes are loaded
    Rails.application.reload_routes!

    # Ensure Devise mappings are loaded
    Devise.mappings[:user] if Devise.respond_to?(:mappings)
  end

  # Ensure Warden is configured properly for each test
  config.before(:each, type: :request) do
    host! 'www.example.com'
  end

  config.after(:each, type: :request) do
    Warden.test_reset! if defined?(Warden)
  end
end
