# frozen_string_literal: true

class SolutionsController < ApplicationController
  # Data schema for polymorphic landing pages
  SOLUTIONS = {
    "schedule-shopify-sales" => {
      headline: "Automate Your Shopify Sale Campaigns",
      subheadline: "Schedule flash sales that start and end automatically—no midnight panic, no manual work.",
      pain_point: "Stop waking up at midnight to manually update prices",
      pain_description: "Running flash sales shouldn't mean setting alarms or staying up late. Your competitors automate this. You should too.",
      logo_image: "solutions/logo.png",
      value_props: [
        {
          title: "Schedule Start & End Times",
          description: "Set your sale to begin and end automatically. Sleep through your flash sales.",
          icon: "clock"
        },
        {
          title: "Automatic Price Reversion",
          description: "Prices restore to original values when the sale ends. Zero manual cleanup.",
          icon: "refresh"
        },
        {
          title: "Campaign Calendar View",
          description: "See all upcoming sales in one dashboard. No spreadsheets needed.",
          icon: "calendar"
        }
      ],
      how_it_works: [
        "Select products by collection, tag, or vendor",
        "Set discount amount ($ or %) and schedule start/end times",
        "Sale activates automatically—prices update across your store",
        "Sale ends on schedule—original prices restore automatically"
      ],
      demo_image: nil, # Set to filename when image is added, e.g., "schedule-demo.png"
      demo_video_url: "https://youtu.be/QaVZkQRHnDM",
      social_proof: "Trusted by Shopify stores running automated sales campaigns",
      cta_primary: "Schedule My First Sale",
      cta_secondary: "See How It Works",
      meta_title: "Automate Shopify Flash Sales | Schedule Price Changes",
      meta_description: "Schedule flash sales that start and end automatically. No midnight panic. Prices revert when sales end. Used by 66,000+ stores.",
      related_keywords: [ "shopify scheduled sales", "automatic flash sales", "shopify price scheduler" ],
      seo_footer_links: [
        { text: "How to Run a Black Friday Campaign", url: "/blogs" },
        { text: "Flash Sale Best Practices", url: "/blogs" },
        { text: "Case Study: 3X Revenue with Scheduled Sales", url: "/case-studies" }
      ]
    },

    "bulk-price-editor" => {
      headline: "Edit 5,000 Products in 30 Seconds",
      subheadline: "Bulk price updates with math operations. No CSV exports. No Excel crashes.",
      pain_point: "Stop crashing Excel with massive CSV imports",
      pain_description: "Shopify's native bulk editor is slow and limited. CSV imports are error-prone and crash with large catalogs. There's a better way.",
      logo_image: "solutions/logo.png",
      demo_video_url: "https://youtu.be/QaVZkQRHnDM",
      value_props: [
        {
          title: "Filter & Select Smart",
          description: "Filter by tag, vendor, collection, price range. Select exactly what you need.",
          icon: "filter"
        },
        {
          title: "Math Operations",
          description: "Apply +/- percentage or fixed amounts. Round prices. Set price floors/ceilings.",
          icon: "calculator"
        },
        {
          title: "Preview Before Apply",
          description: "See exactly what will change before committing. Undo with one click.",
          icon: "eye"
        }
      ],
      how_it_works: [
        "Filter products using advanced criteria (tags, vendors, price ranges)",
        "Select the products you want to modify (or select all)",
        "Apply math operations: +10%, -$5, round to .99, etc.",
        "Preview changes, then apply instantly to your store"
      ],
      social_proof: "Processing 50M+ price updates monthly for Shopify merchants",
      cta_primary: "Edit Prices Now",
      cta_secondary: "Watch Demo",
      meta_title: "Shopify Bulk Price Editor | Update Thousands of Products Fast",
      meta_description: "Edit thousands of Shopify product prices in seconds. Filter, apply math operations, preview changes. No CSV exports or Excel crashes.",
      related_keywords: [ "shopify bulk price editor", "update shopify prices", "shopify price management" ],
      seo_footer_links: [
        { text: "How to Optimize Pricing Strategy", url: "/blogs" },
        { text: "Bulk Editing Best Practices", url: "/blogs" },
        { text: "Product Management at Scale", url: "/blogs" }
      ]
    }
  }.freeze

  def show
    @slug = params[:slug]
    @data = SOLUTIONS[@slug]

    # Handle 404 for undefined slugs
    unless @data
      render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
      return
    end

    # Set page title for layout
    @page_title = @data[:meta_title]
    @page_description = @data[:meta_description]
  end
end
