FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Product #{n}" }
    description { "Product description" }
    tagline { "Product tagline" }
    active { true }
    featured { false }
    featured_on_home { false }
    sequence(:position) { |n| n }
  end
end
