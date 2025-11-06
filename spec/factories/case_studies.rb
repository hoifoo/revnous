FactoryBot.define do
  factory :case_study do
    sequence(:name) { |n| "Case Study #{n}" }
    industry { "Technology" }
    description { "Case study description" }
    challenge { "The client faced challenges with..." }
    solution { "We implemented a solution that..." }
    results { "The results were impressive..." }
    ad_active { false }
  end
end
