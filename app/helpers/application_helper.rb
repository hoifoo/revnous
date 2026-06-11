module ApplicationHelper
  # SEO Meta Tags
  def page_title
    if @page_title.present?
      @page_title
    elsif seo_metadata.present?
      seo_metadata.page_title
    else
      "Revnous - Revenue Optimization for Shopify"
    end
  end

  def page_description
    if @page_description.present?
      @page_description
    elsif seo_metadata.present?
      seo_metadata.meta_description.presence || default_description
    else
      default_description
    end
  end

  def default_description
    "Revnous helps Shopify merchants optimize revenue with powerful pricing tools, analytics, and automation. Maximize your profits with data-driven insights."
  end

  def canonical_url
    @canonical_url || request.original_url.split("?").first
  end

  def page_og_type
    @page_og_type || "website"
  end

  def page_og_image
    if @page_og_image.present?
      @page_og_image
    else
      asset_url("logo.png")
    end
  end

  def page_keywords
    keywords = @page_keywords
    return nil if keywords.blank?

    if keywords.is_a?(Array)
      keywords.compact_blank.join(", ").presence
    else
      keywords.to_s.presence
    end
  end

  def page_robots
    @page_robots || "index, follow"
  end

  # Structured Data (JSON-LD)
  def render_organization_schema
    schema = {
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "@id" => "#{root_url}#organization",
      "name" => "Revnous",
      "url" => root_url,
      "logo" => image_object_schema(asset_url("logo.png")),
      "description" => "Revnous is a Berlin-based software studio that builds and scales its own B2B SaaS products and workflow-automation tools, including Shopify pricing and campaign apps for e-commerce merchants.",
      "slogan" => "Automating the grind.",
      "sameAs" => [
        "https://www.linkedin.com/company/revnous",
        "https://x.com/revnous",
        "https://www.facebook.com/revnous"
      ]
    }

    content_tag :script, json_escape(schema.to_json).html_safe, type: "application/ld+json"
  end

  def render_website_schema
    schema = {
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "@id" => "#{root_url}#website",
      "url" => root_url,
      "name" => "Revnous",
      "description" => "Revnous is a software studio building and scaling B2B SaaS products and automation tools for e-commerce and revenue teams.",
      "publisher" => { "@id" => "#{root_url}#organization" }
    }

    content_tag :script, json_escape(schema.to_json).html_safe, type: "application/ld+json"
  end

  def render_article_schema(article)
    article_url = blog_url(article.slug)

    schema = {
      "@context" => "https://schema.org",
      "@type" => "BlogPosting",
      "@id" => "#{article_url}#article",
      "headline" => article.title,
      "description" => article.seo_description,
      "url" => article_url,
      "mainEntityOfPage" => { "@type" => "WebPage", "@id" => article_url },
      "image" => image_object_schema(article.cover_photo_url, caption: article.title),
      "datePublished" => article.published_at&.iso8601,
      "dateModified" => article.updated_at.iso8601,
      "wordCount" => ActionController::Base.helpers.strip_tags(article.body.to_s).split.size,
      "author" => author_schema_node(article),
      "publisher" => {
        "@type" => "Organization",
        "@id" => "#{root_url}#organization",
        "name" => "Revnous",
        "logo" => image_object_schema(asset_url("logo.png"))
      }
    }.compact

    content_tag :script, json_escape(schema.to_json).html_safe, type: "application/ld+json"
  end

  def render_faq_schema(blog)
    return nil unless blog.respond_to?(:faq_pairs) && blog.faq_pairs.any?

    schema = {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => blog.faq_pairs.map do |pair|
        {
          "@type" => "Question",
          "name" => pair["question"],
          "acceptedAnswer" => {
            "@type" => "Answer",
            "text" => pair["answer"]
          }
        }
      end
    }

    content_tag :script, json_escape(schema.to_json).html_safe, type: "application/ld+json"
  end

  def render_product_schema(product)
    schema = {
      "@context" => "https://schema.org",
      "@type" => "Product",
      "name" => product.name,
      "description" => product.description,
      "image" => image_object_schema(product.cover_photo_url)
    }.compact

    if product.pricing_plans.any?
      schema["offers"] = product.pricing_plans.map do |plan|
        {
          "@type" => "Offer",
          "name" => plan.name,
          "price" => plan.price,
          "priceCurrency" => "USD"
        }
      end
    end

    content_tag :script, json_escape(schema.to_json).html_safe, type: "application/ld+json"
  end

  def render_software_application_schema(product)
    schema = {
      "@context" => "https://schema.org",
      "@type" => "SoftwareApplication",
      "@id" => "#{product_url(product)}#software",
      "name" => product.name,
      "description" => product.description.presence || product.short_description,
      "applicationCategory" => "BusinessApplication",
      "operatingSystem" => "Web",
      "url" => product.url.presence || product_url(product),
      "image" => image_object_schema(product.cover_photo_url)
    }.compact

    if product.pricing_plans.any?
      schema["offers"] = product.pricing_plans.map do |plan|
        {
          "@type" => "Offer",
          "name" => plan.name,
          "price" => plan.price,
          "priceCurrency" => "USD"
        }
      end
    end

    content_tag :script, json_escape(schema.to_json).html_safe, type: "application/ld+json"
  end

  def render_breadcrumbs_schema(breadcrumbs)
    items = breadcrumbs.map.with_index do |crumb, index|
      {
        "@type" => "ListItem",
        "position" => index + 1,
        "name" => crumb[:name],
        "item" => crumb[:url]
      }
    end

    schema = {
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => items
    }

    content_tag :script, json_escape(schema.to_json).html_safe, type: "application/ld+json"
  end

  private

  def image_object_schema(url, caption: nil)
    return nil if url.blank?
    node = { "@type" => "ImageObject", "url" => url, "contentUrl" => url }
    node["caption"] = caption if caption.present?
    node
  end

  def author_schema_node(article)
    if article.respond_to?(:author) && article.author.is_a?(User)
      person = {
        "@type" => "Person",
        "@id" => "#{root_url}#author-#{article.author.id}",
        "name" => article.author.full_name
      }
      person["url"] = article.author.linkedin_url if article.author.linkedin_url.present?
      person["sameAs"] = [ "https://twitter.com/#{article.author.twitter_handle}" ] if article.author.twitter_handle.present?
      person
    else
      { "@type" => "Organization", "@id" => "#{root_url}#organization", "name" => "Revnous" }
    end
  end

  def seo_metadata
    @seo_metadata ||= SeoMetadatum.find_by(page_identifier: controller_path_identifier)
  end

  def controller_path_identifier
    "#{controller_name}##{action_name}"
  end
end
