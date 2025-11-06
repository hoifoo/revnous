FactoryBot.define do
  factory :beta_user do
    association :product
    sequence(:email) { |n| "beta#{n}@example.com" }
    name { "Beta Tester" }
  end
end
