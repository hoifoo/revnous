FactoryBot.define do
  factory :case_study do
    sequence(:title) { |n| "Case Study #{n}" }
    content { "Case study content" }
    client_name { "Example Client" }
    featured { false }
    featured_on_home { false }
  end
end
