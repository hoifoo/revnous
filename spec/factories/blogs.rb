FactoryBot.define do
  factory :blog do
    sequence(:title) { |n| "Blog Post #{n}" }
    sequence(:slug) { |n| "blog-post-#{n}" }
    body { "<p>Blog post content with lots of interesting information.</p>" }
    excerpt { "Short excerpt" }
    published_at { 1.day.ago }
    featured { false }
    featured_on_home { false }

    transient do
      author_user { nil }
    end

    after(:build) do |blog, evaluator|
      blog.author = evaluator.author_user if evaluator.author_user
    end
  end
end
