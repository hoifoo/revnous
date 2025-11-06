FactoryBot.define do
  factory :blog do
    sequence(:title) { |n| "Blog Post #{n}" }
    content { "Blog post content with lots of interesting information." }
    excerpt { "Short excerpt" }
    published_at { 1.day.ago }
    featured { false }
    featured_on_home { false }
  end
end
