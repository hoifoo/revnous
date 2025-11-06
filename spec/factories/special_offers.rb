FactoryBot.define do
  factory :special_offer do
    sequence(:title) { |n| "Test Special Offer #{n}" }
    subtitle { 'Limited time offer' }
    description { 'Test special offer description' }
    terms_text { 'Terms and conditions apply' }
    cta_text { 'Get the offer' }
    cta_url { 'https://example.com/offer' }
    logo_text { 'SPECIAL' }
    active { true }
    placement_tags { [ 'home', 'pricing' ] }
  end
end
