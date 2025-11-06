FactoryBot.define do
  factory :pricing_plan do
    association :product
    sequence(:name) { |n| "Plan #{n}" }
    price { 9.99 }
    billing_period { "monthly" }
    features { [ "Feature 1", "Feature 2", "Feature 3" ] }
    active { true }
    featured { false }
  end
end
