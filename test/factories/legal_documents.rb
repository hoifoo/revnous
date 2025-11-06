FactoryBot.define do
  factory :legal_document do
    association :product
    document_type { "privacy_policy" }
    content { "Legal document content" }
    version { "1.0" }
    active { true }
  end
end
