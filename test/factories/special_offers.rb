FactoryBot.define do
  factory :special_offer do
    sequence(:title) { |n| "Special Offer #{n}" }
    description { "Limited time offer" }
    discount_percentage { 20 }
    starts_at { 1.day.ago }
    ends_at { 30.days.from_now }
    active { true }
    page { "home" }
  end
end
