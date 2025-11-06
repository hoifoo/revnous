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

  factory :blog do
    sequence(:title) { |n| "Blog Post #{n}" }
    content { "Blog post content with lots of interesting information." }
    excerpt { "Short excerpt" }
    published_at { 1.day.ago }
    featured { false }
    featured_on_home { false }
  end

  factory :case_study do
    sequence(:title) { |n| "Case Study #{n}" }
    content { "Case study content" }
    client_name { "Example Client" }
    featured { false }
    featured_on_home { false }
  end

  factory :notice do
    message { "Important notice message" }
    link_text { "Learn more" }
    link_url { "https://example.com" }
    background_color { "#3b82f6" }
    active { true }
  end

  factory :newsletter_subscriber do
    sequence(:email) { |n| "subscriber#{n}@example.com" }
    subscribed_at { Time.current }
    active { true }
  end

  factory :partner do
    sequence(:name) { |n| "Partner #{n}" }
    description { "Partner description" }
    website_url { "https://partner.example.com" }
    active { true }
  end

  factory :pricing_plan do
    association :product
    sequence(:name) { |n| "Plan #{n}" }
    price { 9.99 }
    billing_period { "monthly" }
    features { [ "Feature 1", "Feature 2", "Feature 3" ] }
    active { true }
    featured { false }
  end

  factory :special_offer do
    sequence(:title) { |n| "Special Offer #{n}" }
    description { "Limited time offer" }
    discount_percentage { 20 }
    starts_at { 1.day.ago }
    ends_at { 30.days.from_now }
    active { true }
    page { "home" }
  end

  factory :trusted_brand do
    sequence(:name) { |n| "Brand #{n}" }
    website_url { "https://brand.example.com" }
    active { true }
    sequence(:position) { |n| n }
  end

  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
  end

  factory :beta_user do
    association :product
    sequence(:email) { |n| "beta#{n}@example.com" }
    name { "Beta Tester" }
  end

  factory :legal_document do
    association :product
    document_type { "privacy_policy" }
    content { "Legal document content" }
    version { "1.0" }
    active { true }
  end
end
