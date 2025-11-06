FactoryBot.define do
  factory :notice do
    message { 'Test notice message' }
    link_url { 'https://example.com' }
    link_text { 'Learn More' }
    background_color { 'blue' }
    active { true }
  end
end
