FactoryBot.define do
  factory :pricing_plan do
    association :product
    sequence(:name) { |n| "Plan #{n}" }
    price { 9.99 }
    billing_period { "mo" }
    features { [ "Feature 1", "Feature 2", "Feature 3" ] }
    is_popular { false }
    shopify_plus_only { false }
    position { 0 }
  end
end
