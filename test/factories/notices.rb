FactoryBot.define do
  factory :notice do
    message { "Important notice message" }
    link_text { "Learn more" }
    link_url { "https://example.com" }
    background_color { "#3b82f6" }
    active { true }
  end
end
