FactoryBot.define do
  factory :newsletter_subscriber do
    sequence(:email) { |n| "subscriber#{n}@example.com" }
    subscribed_at { Time.current }
    active { true }
  end
end
