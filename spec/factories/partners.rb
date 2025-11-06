FactoryBot.define do
  factory :partner do
    sequence(:name) { |n| "Partner #{n}" }
    description { "Partner description" }
    website_url { "https://partner.example.com" }
    active { true }
  end
end
