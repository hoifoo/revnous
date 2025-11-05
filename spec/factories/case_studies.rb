FactoryBot.define do
  factory :case_study do
    sequence(:name) { |n| "Test Case Study #{n}" }
    industry { 'Technology' }
    product_features { 'Feature 1, Feature 2' }
    conversion_rate { '25%' }
    ad_active { true }
    content { 'Test case study content' }
  end
end
