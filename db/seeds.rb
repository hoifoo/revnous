# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Create admin user
puts "Creating admin user..."
admin = User.find_or_initialize_by(email: "admin@revnous.com")
admin.password = "password123"
admin.password_confirmation = "password123"
admin.admin = true
admin.save!
puts "Admin user created: #{admin.email} (password: password123)"

# Create notice banner
puts "Creating notice banner..."
Notice.destroy_all
Notice.create!(
  message: "Now live: AI Prompt D-roids. Make every order count more",
  link_url: "https://apps.shopify.com/pricing-schedule",
  link_text: "→",
  background_color: "pink-purple",
  active: true
)
puts "Notice banner created and activated"

# Clear existing case studies
CaseStudy.destroy_all

require "open-uri"

# Create sample case studies based on sale campaign research
case_studies_data = [
  {
    name: "Black Friday Retailer",
    industry: "Retail",
    product_features: "Strategic Discounts",
    ad_active: true,
    description: "Discover how this retailer doubled conversions during Black Friday with a strategic 17.5% discount campaign.",
    conversion_rate: "2x increase",
    revenue_increase: "100% during sale period",
    challenge: "Struggling to capture consumer attention during competitive Black Friday period and convert hesitant customers.",
    solution: "Implemented a well-timed Black Friday campaign with an average discount of 17.5%, creating urgency and FOMO among shoppers.",
    results: "Near doubling of conversions during the Black Friday sales period, demonstrating the immense power of strategic price reductions.",
    image_url: "https://images.unsplash.com/photo-1607083206869-4c7672e72a8a?w=500&h=400&fit=crop"
  },
  {
    name: "Fashion Flash Sale",
    industry: "Fashion & Apparel",
    product_features: "Flash Sales",
    ad_active: true,
    description: "Learn how a fashion retailer generated 17% of monthly sales in just 6 hours using flash sale tactics.",
    conversion_rate: "Massive spike",
    revenue_increase: "17% of monthly revenue in 6 hours",
    challenge: "Low conversion rates and difficulty creating urgency for immediate purchases.",
    solution: "Launched a limited-time flash sale heavily promoted through email and social media, leveraging the ephemeral nature to create psychological triggers.",
    results: "Generated 17% of total monthly sales within a mere six-hour window, compelling consumers to purchase immediately.",
    image_url: "https://images.unsplash.com/photo-1445205170230-053b83016050?w=500&h=400&fit=crop"
  },
  {
    name: "Premium Brand Strategy",
    industry: "Luxury Goods",
    product_features: "Value-Added Promotions",
    ad_active: true,
    description: "See how a luxury brand maintained premium positioning while boosting sales with value-added promotions instead of discounts.",
    conversion_rate: "35% increase",
    revenue_increase: "42% without margin erosion",
    challenge: "Need to drive sales without devaluing the brand through frequent discounts that could damage premium positioning.",
    solution: "Replaced straight price cuts with value-added incentives: BOGO offers, free shipping, and gifts with purchase to preserve brand integrity.",
    results: "Increased conversions by 35% while maintaining profit margins and brand perception, attracting quality customers loyal to the brand.",
    image_url: "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=500&h=400&fit=crop"
  },
  {
    name: "Segmented Offers Retailer",
    industry: "E-commerce",
    product_features: "Targeted Discounts",
    ad_active: true,
    description: "How targeted segment-specific offers outperformed blanket discounts by 3x in customer lifetime value.",
    conversion_rate: "28% increase",
    revenue_increase: "3x customer LTV",
    challenge: "Blanket discounts were attracting bargain hunters with low repeat purchase rates and diminishing brand loyalty.",
    solution: "Replaced site-wide sales with segmented offers: welcome discounts for new subscribers, loyalty rewards for repeat customers, and re-engagement offers for lapsed buyers.",
    results: "28% conversion increase with 3x higher customer lifetime value compared to bargain hunters, building a loyal customer base.",
    image_url: "https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=500&h=400&fit=crop"
  },
  {
    name: "Rule of 100 Case Study",
    industry: "Electronics & Accessories",
    product_features: "Discount Framing",
    ad_active: true,
    description: "Discover how strategic discount framing using the Rule of 100 increased perceived value and conversions.",
    conversion_rate: "22% increase",
    revenue_increase: "19% revenue lift",
    challenge: "Ineffective discount presentation leading to lower perceived value and conversion rates.",
    solution: "Applied the Rule of 100: percentage discounts for products under $100, fixed-amount discounts for products over $100, optimizing psychological impact.",
    results: "22% increase in conversion rates with customers perceiving greater value, leading to a 19% overall revenue lift.",
    image_url: "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=500&h=400&fit=crop"
  },
  {
    name: "Seasonal Timing Strategy",
    industry: "Home & Garden",
    product_features: "Strategic Timing",
    ad_active: true,
    description: "How tying promotions to specific seasons prevented brand devaluation while driving consistent sales.",
    conversion_rate: "45% during seasons",
    revenue_increase: "32% annual increase",
    challenge: "Constant discounts were training customers to wait for sales and eroding brand value perception.",
    solution: "Limited promotions to key seasonal events and holidays, creating a sense of occasion and maintaining full-price credibility between campaigns.",
    results: "45% conversion spike during promotional periods with 32% annual revenue increase, while preserving brand integrity and full-price sales.",
    image_url: "https://images.unsplash.com/photo-1484101403633-562f891dc89a?w=500&h=400&fit=crop"
  },
  {
    name: "Customer Training Recovery",
    industry: "Beauty & Personal Care",
    product_features: "Sales Strategy Reversal",
    ad_active: false,
    description: "How a brand recovered from discount addiction by retraining customers to appreciate full-price value.",
    conversion_rate: "Recovered to baseline",
    revenue_increase: "65% margin improvement",
    challenge: "Customers trained to wait for sales, creating boom-bust revenue cycles and 40% profit margin erosion.",
    solution: "Phased out frequent discounts, emphasized product quality and benefits, introduced loyalty programs, and limited sales to quarterly events only.",
    results: "Successfully retrained customer base over 6 months, recovering full-price conversions and improving margins by 65%.",
    image_url: "https://images.unsplash.com/photo-1596755389378-c31d21fd1273?w=500&h=400&fit=crop"
  },
  {
    name: "A/B Testing Success",
    industry: "Fashion & Apparel",
    product_features: "Data-Driven Optimization",
    ad_active: true,
    description: "How systematic A/B testing of discount types and thresholds optimized conversion without margin sacrifice.",
    conversion_rate: "31% increase",
    revenue_increase: "24% with maintained margins",
    challenge: "Uncertain about optimal discount levels and formats - guessing was leaving money on the table.",
    solution: "Implemented rigorous A/B testing program comparing percentage vs. fixed discounts, different threshold levels, and promotional messaging across customer segments.",
    results: "Found optimal discount strategy: 15% off for new customers, $20 off orders over $150 for returnees - achieving 31% conversion lift while protecting margins.",
    image_url: "https://images.unsplash.com/photo-1483985988355-763728e1935b?w=500&h=400&fit=crop"
  },
  {
    name: "BOGO Value Strategy",
    industry: "Health & Wellness",
    product_features: "Value-Added Offers",
    ad_active: true,
    description: "Learn how BOGO offers increased perceived value more than equivalent percentage discounts.",
    conversion_rate: "38% higher than discount",
    revenue_increase: "52% AOV increase",
    challenge: "Standard percentage discounts were devaluing products and not maximizing average order value.",
    solution: "Replaced 50% off sales with Buy One Get One 50% Off and bundle deals, emphasizing value addition rather than price reduction.",
    results: "38% higher conversion than equivalent percentage discounts, 52% increase in average order value, and better brand perception.",
    image_url: "https://images.unsplash.com/photo-1593095948071-474c5cc2989d?w=500&h=400&fit=crop"
  },
  {
    name: "Free Shipping Threshold",
    industry: "Home Goods",
    product_features: "Strategic Incentives",
    ad_active: true,
    description: "How free shipping thresholds outperformed straight discounts in driving both conversions and AOV.",
    conversion_rate: "41% cart completion",
    revenue_increase: "47% AOV increase",
    challenge: "High cart abandonment rates and low average order values despite promotional efforts.",
    solution: "Replaced percentage discounts with free shipping on orders over $75, strategically set just above average order value.",
    results: "41% improvement in cart completion rate, 47% increase in AOV as customers added items to qualify, without margin erosion.",
    image_url: "https://images.unsplash.com/photo-1556911261-6bd341186b2f?w=500&h=400&fit=crop"
  },
  {
    name: "Welcome Discount Optimization",
    industry: "Subscription Box",
    product_features: "New Customer Acquisition",
    ad_active: true,
    description: "Optimizing first-purchase discounts to maximize new customer acquisition while protecting LTV.",
    conversion_rate: "67% new visitor conversion",
    revenue_increase: "89% subscription retention",
    challenge: "Needed to convert new visitors without attracting discount-dependent customers with low retention.",
    solution: "Tested various welcome offers, settled on 20% off first box + free gift, emphasizing product value and subscription benefits over price.",
    results: "67% first-time visitor conversion with 89% subscription retention rate after 3 months - proving quality customer acquisition.",
    image_url: "https://images.unsplash.com/photo-1607083206325-caf1edba7a0f?w=500&h=400&fit=crop"
  }
]

case_studies_data.each do |data|
  image_url = data.delete(:image_url)
  case_study = CaseStudy.create!(data)

  if image_url
    begin
      downloaded_image = URI.open(image_url)
      case_study.image.attach(
        io: downloaded_image,
        filename: "#{case_study.name.parameterize}.jpg",
        content_type: "image/jpeg"
      )
      puts "Attached image for #{case_study.name}"
    rescue => e
      puts "Failed to attach image for #{case_study.name}: #{e.message}"
    end
  end
end

puts "Created #{CaseStudy.count} case studies with images"

# Clear existing blogs
Blog.destroy_all

# Create sample blog posts
blogs_data = [
  {
    title: "The Ultimate Guide to Black Friday Sales Strategies for 2024",
    author: "Sarah Chen",
    published_at: 2.weeks.ago,
    category: "Sales Strategy",
    excerpt: "Discover data-backed strategies to maximize your Black Friday revenue without sacrificing your brand value. Learn from retailers who doubled their conversions.",
    content: "Black Friday represents the single biggest opportunity for eCommerce brands to drive revenue, but it's also when most brands make critical mistakes that damage their long-term profitability.\n\nOur research shows that the average Black Friday discount of 17.5% led to near-doubling of conversions. But here's what most retailers miss: the timing, presentation, and customer segmentation matter just as much as the discount itself.\n\nSuccessful Black Friday campaigns share three key characteristics:\n\n1. Strategic Discount Levels: Not too deep (erodes margins), not too shallow (fails to convert)\n2. Urgency Creation: Limited-time offers that create genuine FOMO\n3. Targeted Segmentation: Different offers for different customer segments\n\nOne fashion retailer we studied generated 17% of their entire monthly revenue in just 6 hours by implementing these principles. They didn't offer the deepest discounts - they offered the most strategically timed and presented ones.\n\nThe key takeaway? Stop competing on price alone. Compete on value, urgency, and customer experience.",
    featured: true,
    featured_on_home: true,
    image_url: "https://images.unsplash.com/photo-1607083206869-4c7672e72a8a?w=800&h=600&fit=crop"
  },
  {
    title: "How Premium Brands Can Run Sales Without Devaluing Their Products",
    author: "Marcus Thompson",
    published_at: 1.week.ago,
    category: "Brand Strategy",
    excerpt: "Luxury and premium brands face a unique challenge: driving sales without damaging brand perception. Here's how to do it right.",
    content: "The luxury brand dilemma: you need to drive revenue, but every discount risks devaluing your brand in customers' eyes.\n\nWe analyzed dozens of premium brands and found a clear pattern among those who successfully maintained their positioning while growing revenue: they never compete on price.\n\nInstead, they use value-added promotions:\n- Buy One Get One offers\n- Gifts with purchase\n- Free premium shipping\n- Exclusive early access\n- Limited edition bundles\n\nOne luxury retailer increased conversions by 35% and revenue by 42% without a single percentage-off sale. Their secret? Emphasizing exclusivity and added value rather than discounts.\n\nThe math is simple: a 50% discount might double your sales temporarily, but it trains customers to wait for sales and attracts bargain hunters who'll never become loyal customers.\n\nValue-added promotions, on the other hand, increase perceived value while maintaining price integrity. You're giving more, not charging less.",
    featured: false,
    image_url: "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800&h=600&fit=crop"
  },
  {
    title: "The Psychology of Discount Framing: The Rule of 100",
    author: "Dr. Emily Rodriguez",
    published_at: 3.days.ago,
    category: "Psychology",
    excerpt: "Why '$20 off' converts better than '20% off' for some products, and vice versa. The neuroscience behind discount perception.",
    content: "Here's a simple question that most eCommerce brands get wrong: should you advertise '20% off' or '$20 off'?\n\nThe answer depends on your price point, and it's rooted in behavioral psychology.\n\nThe Rule of 100 states:\n- For products under $100: percentage discounts appear larger\n- For products over $100: absolute dollar discounts appear larger\n\nWhy? Because our brains compare discount numbers to the base number 100.\n\n'20% off' sounds better than '$15 off' because 20 > 15.\n'$30 off' sounds better than '15% off' because 30 > 15.\n\nOne electronics retailer applied this principle across their entire catalog and saw a 22% increase in conversion rates, leading to a 19% revenue lift - with zero change to their actual discount levels.\n\nThis isn't manipulation; it's communication optimization. You're presenting the same value in the way that resonates most with how humans process numerical information.\n\nThe lesson? Test your discount framing. The difference between '25% off' and '$25 off' could be thousands in revenue.",
    featured: true,
    featured_on_home: true,
    image_url: "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&h=600&fit=crop"
  },
  {
    title: "Why Your Customers Are Trained to Wait for Sales (And How to Fix It)",
    author: "James Liu",
    published_at: 5.days.ago,
    category: "Customer Behavior",
    excerpt: "Constant discounting creates a vicious cycle. Learn how one brand recovered from discount addiction and improved margins by 65%.",
    content: "If you're running sales every week, you've trained your customers to never buy at full price. Here's how that happened - and how to reverse it.\n\nThe Discount Addiction Cycle:\n1. You run a sale to boost revenue\n2. Customers make purchases, revenue spikes\n3. After the sale, purchases drop below baseline\n4. Panicked, you run another sale\n5. Repeat until full-price sales approach zero\n\nOne beauty brand found themselves in exactly this situation. Sales had become so frequent that 85% of purchases happened during promotions. Their margins had eroded by 40%.\n\nHere's what they did to recover:\n\nPhase 1 (Months 1-2): Reduced sale frequency to monthly\nPhase 2 (Months 3-4): Shifted to quarterly sales only\nPhase 3 (Months 5-6): Enhanced product storytelling and value proposition\nPhase 4 (Ongoing): Loyalty programs for repeat customers\n\nThe result? After 6 months, full-price conversions recovered to baseline, and profit margins improved by 65%.\n\nThe key insight: customers need to be retrained to value your products at full price. This requires patience, but the long-term payoff is substantial.",
    featured: false,
    image_url: "https://images.unsplash.com/photo-1596755389378-c31d21fd1273?w=800&h=600&fit=crop"
  },
  {
    title: "Flash Sales vs. Scheduled Sales: Which Drives More Revenue?",
    author: "Sarah Chen",
    published_at: 1.week.ago,
    category: "Sales Strategy",
    excerpt: "We analyzed 500+ sales campaigns to determine whether surprise flash sales or scheduled promotional events generate better results.",
    content: "The debate: should you announce sales in advance, or surprise customers with flash sales?\n\nOur data analysis of 500+ campaigns reveals the answer is nuanced - but actionable.\n\nFlash Sales Win For:\n- Creating urgency (43% higher conversion rates)\n- Clearing inventory quickly\n- Generating social media buzz\n- Attracting new customers\n\nScheduled Sales Win For:\n- Building anticipation\n- Higher average order values (28% higher)\n- Better customer satisfaction\n- Loyalty program engagement\n\nBut here's the real finding: the most successful brands use BOTH strategically.\n\nThey run 3-4 major scheduled sales per year (tied to seasons/holidays) for maximum revenue, and 2-3 surprise flash sales for buzz and urgency.\n\nOne fashion retailer generated 17% of monthly revenue in just 6 hours with a flash sale - but their scheduled Black Friday event drove 34% of their quarterly revenue.\n\nThe lesson? Diversify your promotional strategy. Each sale type serves a different purpose in your overall revenue optimization strategy.",
    featured: false,
    image_url: "https://images.unsplash.com/photo-1445205170230-053b83016050?w=800&h=600&fit=crop"
  },
  {
    title: "Free Shipping Thresholds: The Hidden Conversion Lever",
    author: "Marcus Thompson",
    published_at: 4.days.ago,
    category: "Conversion Optimization",
    excerpt: "Why free shipping thresholds outperform percentage discounts in driving both conversions and average order value.",
    content: "What if I told you that 'Free Shipping on Orders Over $75' could outperform '15% Off Everything'?\n\nIt sounds counterintuitive, but our research shows free shipping thresholds deliver superior results on two critical metrics:\n\n1. Cart Completion Rate: +41%\n2. Average Order Value: +47%\n\nHere's why it works:\n\nPsychological Framing: 'Free' is the most powerful word in marketing. Customers perceive shipping as a loss, not just a cost.\n\nStrategic Anchoring: Set your threshold slightly above your current AOV, and customers add items to qualify.\n\nMargin Protection: Unlike percentage discounts, shipping thresholds don't erode product margins.\n\nOne home goods retailer replaced their 20% off sale with free shipping over $75 (their AOV was $52). Results:\n- Cart abandonment dropped from 68% to 39%\n- Average order value increased from $52 to $76\n- Gross margin improved by 12%\n\nThe key is threshold optimization. Too low, and you're just absorbing shipping costs. Too high, and you won't change behavior.\n\nOur recommendation: Set your threshold 20-30% above your current AOV for optimal results.",
    featured: false,
    image_url: "https://images.unsplash.com/photo-1556911261-6bd341186b2f?w=800&h=600&fit=crop"
  },
  {
    title: "A/B Testing Your Discount Strategy: A Step-by-Step Guide",
    author: "Dr. Emily Rodriguez",
    published_at: 2.days.ago,
    category: "Testing & Optimization",
    excerpt: "Stop guessing which discounts work best. Here's how to systematically test and optimize your promotional strategy.",
    content: "Most brands guess at their discount strategy. The best brands test it systematically.\n\nHere's our proven A/B testing framework for promotional optimization:\n\nTest 1: Discount Type\nVariant A: 20% off\nVariant B: $20 off\nMetric: Conversion rate by price point\n\nTest 2: Discount Depth\nVariant A: 15% off\nVariant B: 25% off\nMetric: Revenue and margin impact\n\nTest 3: Promotional Format\nVariant A: Site-wide sale\nVariant B: Tiered discounts ($10 off $50, $25 off $100)\nMetric: Average order value\n\nTest 4: Messaging\nVariant A: 'Save 20%'\nVariant B: 'Members Save 20%'\nMetric: Perceived value and conversion\n\nOne fashion retailer ran this exact sequence and discovered:\n- 15% off for new customers (vs 20%): Same conversion, +5% margin\n- $20 off $150 for returning customers: +31% conversion vs percentage discount\n- 'Member Exclusive' messaging: +18% conversion vs generic discount\n\nThe result: 31% overall conversion lift while maintaining margins.\n\nThe key lesson: every audience is different. What works for one brand may not work for yours. Test everything.",
    featured: true,
    featured_on_home: true,
    image_url: "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&h=600&fit=crop"
  },
  {
    title: "Segmented Discounts: Why One-Size-Fits-All Sales Are Leaving Money on the Table",
    author: "James Liu",
    published_at: 6.days.ago,
    category: "Customer Segmentation",
    excerpt: "How targeted offers to different customer segments can 3x your customer lifetime value compared to blanket discounts.",
    content: "Site-wide sales seem simple and fair. But they're also inefficient and potentially damaging to your business.\n\nHere's why: different customer segments have different price sensitivities and lifetime values.\n\nBlanket 25% off to everyone means:\n- You're over-discounting to loyal customers who would have bought anyway\n- You're attracting bargain hunters who'll never return\n- You're training your best customers to wait for sales\n\nThe alternative? Segmented offers:\n\nNew Visitors: 15% off first purchase + email capture\nLoyal Customers: Early access + exclusive perks (no discount needed)\nLapsed Customers: 20% off 'We miss you' campaign\nCart Abandoners: Free shipping to complete purchase\nHigh-Value Customers: VIP rewards, not discounts\n\nOne retailer switched from site-wide sales to this segmented approach:\n\nResults after 3 months:\n- Overall conversion: +28%\n- Customer lifetime value: 3x higher\n- Repeat purchase rate: +45%\n- Profit margin: +22%\n\nThe key insight: not all customers need the same incentive. Sophisticated segmentation allows you to optimize for both conversion AND lifetime value.\n\nYour most loyal customers don't want discounts - they want recognition and exclusive access.",
    featured: false,
    image_url: "https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=800&h=600&fit=crop"
  }
]

blogs_data.each do |data|
  image_url = data.delete(:image_url)
  blog = Blog.create!(data)

  if image_url
    begin
      downloaded_image = URI.open(image_url)
      blog.image.attach(
        io: downloaded_image,
        filename: "#{blog.slug}.jpg",
        content_type: "image/jpeg"
      )
      puts "Attached image for #{blog.title}"
    rescue => e
      puts "Failed to attach image for #{blog.title}: #{e.message}"
    end
  end
end

puts "Created #{Blog.count} blog posts with images"

# Clear existing products and pricing plans
Product.destroy_all
PricingPlan.destroy_all

# Create products
products_data = [
  {
    name: "Revnous for Shopify",
    product_type: "Shopify App",
    url: "https://apps.shopify.com/pricing-schedule",
    short_description: "Complete revenue optimization platform for Shopify stores",
    description: "Revnous for Shopify is the most powerful revenue optimization app that helps eCommerce brands increase conversions, boost AOV, and drive sustainable growth through strategic sales campaigns, post-purchase upsells, and checkout customization.",
    featured: true,
    featured_on_home: true,
    active: true,
    position: 1,
    cover_photo_url: "https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=1200&h=800&fit=crop",
    logo_url: "https://images.unsplash.com/photo-1563986768609-322da13575f3?w=200&h=200&fit=crop"
  }
]

products_data.each do |product_data|
  cover_photo_url = product_data.delete(:cover_photo_url)
  logo_url = product_data.delete(:logo_url)

  product = Product.create!(product_data)

  # Attach cover photo
  if cover_photo_url
    begin
      downloaded_cover = URI.open(cover_photo_url)
      product.cover_photo.attach(
        io: downloaded_cover,
        filename: "#{product.name.parameterize}-cover.jpg",
        content_type: "image/jpeg"
      )
      puts "Attached cover photo for #{product.name}"
    rescue => e
      puts "Failed to attach cover photo for #{product.name}: #{e.message}"
    end
  end

  # Attach logo
  if logo_url
    begin
      downloaded_logo = URI.open(logo_url)
      product.logo.attach(
        io: downloaded_logo,
        filename: "#{product.name.parameterize}-logo.jpg",
        content_type: "image/jpeg"
      )
      puts "Attached logo for #{product.name}"
    rescue => e
      puts "Failed to attach logo for #{product.name}: #{e.message}"
    end
  end

  puts "Created product: #{product.name}"
end

puts "Created #{Product.count} products"

# Get the Shopify app product
shopify_app = Product.find_by(name: "Revnous for Shopify")

# Create pricing plans linked to the product
pricing_plans_data = [
  {
    name: "Post Purchase",
    price: 34.99,
    billing_period: "mo",
    order_limit: "100 total store orders per month",
    cta_text: "Try Now for Free",
    cta_url: "https://apps.shopify.com/pricing-schedule",
    trial_text: "30-day free trial · Only available on Shopify Plus",
    is_popular: false,
    shopify_plus_only: true,
    position: 1,
    product_id: shopify_app.id,
    features: [
      "Unlimited offers",
      "Smart funnels",
      "Google targeting",
      "Language translations",
      "Advanced product rules",
      "A/B testing"
    ]
  },
  {
    name: "Checkout",
    price: 99,
    billing_period: "mo",
    order_limit: nil,
    cta_text: "Try Checkout today",
    cta_url: "https://apps.shopify.com/pricing-schedule",
    trial_text: "30-day free trial · Only available on Shopify Plus",
    is_popular: true,
    shopify_plus_only: true,
    position: 2,
    product_id: shopify_app.id,
    features: [
      "Customized checkout",
      "Trust badges",
      "Upsell offers",
      "Reviews widgets",
      "Countdown timers",
      "Checkout branding"
    ]
  },
  {
    name: "Cart Drawer",
    price: 29.99,
    billing_period: "mo",
    order_limit: "200 total store orders per month",
    cta_text: "Try Now for Free",
    cta_url: "https://apps.shopify.com/pricing-schedule",
    trial_text: "30-day free trial · Compatible with all Shopify stores",
    is_popular: false,
    shopify_plus_only: false,
    position: 3,
    product_id: shopify_app.id,
    features: [
      "Optimized cart drawer",
      "Subscription upsells",
      "Unlimited offers",
      "Strong gamification",
      "Product add-ons",
      "Product edit only"
    ]
  },
  {
    name: "Rokt Thanks",
    price: nil,
    billing_period: "mo",
    order_limit: nil,
    cta_text: "Get $5 for $0 for your per sale",
    cta_url: "https://apps.shopify.com/pricing-schedule",
    description: "New customers receive $0.00 - $0.50 commission fee back. Driven+ and Boost can uplift net revenue ~10%-30% on your thank you page.",
    trial_text: "Requires installation of Liftoff by Rokt",
    is_popular: false,
    shopify_plus_only: false,
    position: 4,
    product_id: shopify_app.id,
    features: [
      "You pay $0 till upfront—we handle it"
    ]
  }
]

pricing_plans_data.each do |plan_data|
  features = plan_data.delete(:features)
  plan = PricingPlan.create!(plan_data)
  plan.features_list = features if features
  plan.save!
  puts "Created pricing plan: #{plan.name}"
end

puts "Created #{PricingPlan.count} pricing plans"

# Clear existing trusted brands
TrustedBrand.destroy_all

# Create trusted brands
trusted_brands_data = [
  { name: "HEXCLAD", font_style: "bold", position: 1 },
  { name: "TRUE CLASSIC", font_style: "bold", position: 2 },
  { name: "David", font_style: "serif", position: 3 },
  { name: "RIDGE", font_style: "bold", position: 4 },
  { name: "/kit·sch/", font_style: "light", position: 5 },
  { name: "PRINCE", font_style: "bold", position: 6 }
]

trusted_brands_data.each do |brand_data|
  TrustedBrand.create!(brand_data)
  puts "Created trusted brand: #{brand_data[:name]}"
end

puts "Created #{TrustedBrand.count} trusted brands"

# Clear existing special offers
SpecialOffer.destroy_all

# Create special offers
special_offers_data = [
  {
    title: "Recently upgraded to Shopify Plus?",
    subtitle: "EXCLUSIVE OFFER",
    description: "Receive free lifetime access to Revnous's checkout functionality ($1200 annual value). Want to unlock the full Revnous suite for free? Connect with us, learn and get your offer.",
    terms_text: "*Terms apply",
    cta_text: "Get the offer",
    cta_url: "https://calendar.app.google/ExeXXoFRYB52hu5S8",
    logo_text: "Shopify+",
    active: true,
    placement_tags: [ "pricing" ]
  }
]

special_offers_data.each do |offer_data|
  placement_tags = offer_data.delete(:placement_tags)
  offer = SpecialOffer.create!(offer_data)
  offer.placement_tags_list = placement_tags if placement_tags
  offer.save!
  puts "Created special offer: #{offer.title}"
end

puts "Created #{SpecialOffer.count} special offers"

# Clear existing partners
Partner.destroy_all

# Create partners
partners_data = [
  {
    name: "Shopify",
    website_url: "https://www.shopify.com",
    description: "Leading e-commerce platform powering millions of businesses worldwide",
    active: true,
    position: 1
  },
  {
    name: "Stripe",
    website_url: "https://stripe.com",
    description: "Payment processing platform trusted by businesses of all sizes",
    active: true,
    position: 2
  },
  {
    name: "Amazon",
    website_url: "https://www.amazon.com",
    description: "Global e-commerce and cloud computing leader",
    active: true,
    position: 3
  },
  {
    name: "Google",
    website_url: "https://www.google.com",
    description: "Technology leader in search, advertising, and cloud services",
    active: true,
    position: 4
  },
  {
    name: "Meta",
    website_url: "https://www.meta.com",
    description: "Social technology company connecting billions of people worldwide",
    active: true,
    position: 5
  },
  {
    name: "Salesforce",
    website_url: "https://www.salesforce.com",
    description: "Customer relationship management platform leader",
    active: true,
    position: 6
  }
]

partners_data.each do |partner_data|
  Partner.create!(partner_data)
  puts "Created partner: #{partner_data[:name]}"
end

puts "Created #{Partner.count} partners"
