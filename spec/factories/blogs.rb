FactoryBot.define do
  factory :blog do
    sequence(:title) { |n| "Test Blog Post #{n}" }
    sequence(:slug) { |n| "test-blog-post-#{n}" }
    content { 'Test blog content' }
    author { 'Test Author' }
    category { 'Technology' }
    published_at { Time.current }
    featured { false }
    featured_on_home { false }
  end
end
