FactoryBot.define do
  factory :user do
    email { Faker::Internet.unique.email }
    password { 'password123' }
    password_confirmation { 'password123' }
    first_name { 'Test' }
    last_name { 'User' }
    admin { false }

    trait :admin do
      admin { true }
      first_name { 'Admin' }
      last_name { 'User' }
    end
  end
end
