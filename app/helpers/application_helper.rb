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

  def page_robots
    @page_robots || "index, follow"
  end

  # Structured Data (JSON-LD)
  def render_organization_schema
    schema = {
      "@context": "https://schema.org",
      "@type": "Organization",
      "name": "Revnous",
      "url": root_url,
      "logo": asset_url("logo.png"),
      "description": "Revenue optimization tools for Shopify merchants",
      "sameAs": [
        # Add your social media URLs here when available
      ]
    }

    content_tag :script, schema.to_json.html_safe, type: "application/ld+json"
  end

  def render_article_schema(article)
    schema = {
      "@context": "https://schema.org",
      "@type": "Article",
      "headline": article.title,
      "description": article.meta_description || article.excerpt,
      "image": article.cover_photo_url,
      "datePublished": article.created_at.iso8601,
      "dateModified": article.updated_at.iso8601,
      "author": {
        "@type": "Organization",
        "name": "Revnous"
      },
      "publisher": {
        "@type": "Organization",
        "name": "Revnous",
        "logo": {
          "@type": "ImageObject",
          "url": asset_url("logo.png")
        }
      }
    }

    content_tag :script, schema.to_json.html_safe, type: "application/ld+json"
  end

  def render_product_schema(product)
    schema = {
      "@context": "https://schema.org",
      "@type": "Product",
      "name": product.name,
      "description": product.description,
      "image": product.cover_photo_url
    }

    # Add offers if pricing plans exist
    if product.pricing_plans.any?
      schema[:offers] = product.pricing_plans.map do |plan|
        {
          "@type": "Offer",
          "name": plan.name,
          "price": plan.price,
          "priceCurrency": "USD"
        }
      end
    end

    content_tag :script, schema.to_json.html_safe, type: "application/ld+json"
  end

  def render_breadcrumbs_schema(breadcrumbs)
    items = breadcrumbs.map.with_index do |crumb, index|
      {
        "@type": "ListItem",
        "position": index + 1,
        "name": crumb[:name],
        "item": crumb[:url]
      }
    end

    schema = {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      "itemListElement": items
    }

    content_tag :script, schema.to_json.html_safe, type: "application/ld+json"
  end

  private

  def seo_metadata
    @seo_metadata ||= SeoMetadatum.find_by(page_identifier: controller_path_identifier)
  end

  def controller_path_identifier
    # Generate identifier like "home#index" or "blogs#show"
    "#{controller_name}##{action_name}"
  end
end
