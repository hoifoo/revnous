# Public social-proof numbers and customer reviews shown across the marketing site.
# Update this file (only) when the numbers change. Keep every figure verifiable:
# stats come from the Pricing Schedule admin dashboard, rating and reviews from
# the Shopify App Store listing. Reviews must be quoted verbatim.
module SocialProof
  SHOPIFY_APP_URL = "https://apps.shopify.com/pricing-schedule".freeze
  SHOPIFY_REVIEWS_URL = "https://apps.shopify.com/pricing-schedule/reviews".freeze

  MERCHANT_COUNT = "100+".freeze
  MERCHANTS_LABEL = "#{MERCHANT_COUNT} Shopify merchants".freeze
  RATING = "4.8".freeze
  RATING_LABEL = "#{RATING}/5 on the Shopify App Store".freeze

  AI_ASSISTANT_EXAMPLE = "20% off the Winter collection from Friday 9am to Monday midnight".freeze

  # As of 2026-11-13 (dashboard: 130,952 product schedules, 740,079 variants).
  PRODUCT_SCHEDULES = "130K+".freeze
  VARIANT_CHANGES = "740K+".freeze

  STATS = [
    { value: MERCHANT_COUNT, label: "Shopify merchants" },
    { value: PRODUCT_SCHEDULES, label: "Product price schedules" },
    { value: VARIANT_CHANGES, label: "Variant price changes automated" },
    { value: "#{RATING}/5", label: "Shopify App Store rating", url: SHOPIFY_REVIEWS_URL }
  ].freeze

  REVIEWS = [
    {
      store: "Tiny Tales",
      country: "India",
      quote: "Works as smooth as a butter and Customer service was super fast. I would definitely recommend using this app."
    },
    {
      store: "SlothBedding",
      country: "Türkiye",
      quote: "This app has saved us a lot of time when running discounts and scheduled sales. Instead of changing prices manually, we can plan everything in advance and let the app handle it. Simple to use, reliable, and very practical for managing campaigns."
    },
    {
      store: "Sadece Satranç",
      country: "Türkiye",
      quote: "I’ve started using Revnous Bulk Pricing Editor to schedule price changes and sales in my store, and it’s made things so much easier. No more doing price updates manually every time. I just plan my campaigns ahead and let it run. Works smoothly, and even the free plan is super useful!"
    }
  ].freeze
end
