FactoryBot.define do
  factory :legal_document do
    sequence(:title) { |n| "Test Legal Document #{n}" }
    sequence(:slug) { |n| "test-legal-document-#{n}" }
    content { 'Test legal document content' }
    document_type { 'privacy_policy' }
    active { true }
    version { '1.0' }
    effective_date { Date.today }

    trait :terms_of_service do
      document_type { 'terms_of_service' }
      sequence(:slug) { |n| "test-terms-#{n}" }
    end
  end
end
