FactoryBot.define do
  factory :partner do
    sequence(:name) { |n| "Test Partner #{n}" }
    website_url { 'https://example.com' }
    description { 'Test partner description' }
    active { true }
    position { 0 }
  end
end
