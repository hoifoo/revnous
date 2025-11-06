FactoryBot.define do
  factory :pricing_plan do
    association :product
    sequence(:name) { |n| "Test Plan #{n}" }
    price { 29.99 }
    billing_period { 'mo' }
    description { 'Test pricing plan description' }
    order_limit { '100 orders/month' }
    cta_text { 'Try Now for Free' }
    cta_url { 'https://example.com/signup' }
    trial_text { '14-day free trial' }
    is_popular { false }
    shopify_plus_only { false }
    position { 0 }
    features { ['Feature 1', 'Feature 2', 'Feature 3'] }
  end
end
