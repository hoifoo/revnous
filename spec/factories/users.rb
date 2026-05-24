FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:first_name) { |n| "First#{n}" }
    sequence(:last_name) { |n| "Last#{n}" }
    password { "password123" }
    password_confirmation { "password123" }
    admin { false }
    job_title { "Content Marketing Manager" }
    bio { "A short bio for testing." }
    linkedin_url { nil }
    twitter_handle { nil }

    trait :admin do
      admin { true }
    end
  end
end
