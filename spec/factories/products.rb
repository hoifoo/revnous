FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Test Product #{n}" }
    product_type { 'subscription' }
    url { 'https://example.com/product' }
    short_description { 'A short description of the product' }
    description { 'A detailed description of the product' }
    featured { false }
    featured_on_home { false }
    active { true }
    position { 0 }
  end
end
