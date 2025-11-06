FactoryBot.define do
  factory :trusted_brand do
    sequence(:name) { |n| "Test Brand #{n}" }
    font_style { 'bold' }
    position { 0 }
  end
end
