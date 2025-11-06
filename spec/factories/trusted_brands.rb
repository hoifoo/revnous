FactoryBot.define do
  factory :trusted_brand do
    sequence(:name) { |n| "Brand #{n}" }
    font_style { "bold" }
    sequence(:position) { |n| n }
  end
end
