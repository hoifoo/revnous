FactoryBot.define do
  factory :trusted_brand do
    sequence(:name) { |n| "Brand #{n}" }
    website_url { "https://brand.example.com" }
    active { true }
    sequence(:position) { |n| n }
  end
end
