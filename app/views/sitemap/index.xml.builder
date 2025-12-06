xml.instruct!
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  # Homepage
  xml.url do
    xml.loc root_url
    xml.lastmod Time.current.to_date
    xml.changefreq "daily"
    xml.priority 1.0
  end

  # Static pages
  [
    { path: products_url, changefreq: "weekly", priority: 0.9 },
    { path: case_studies_url, changefreq: "weekly", priority: 0.9 },
    { path: blogs_url, changefreq: "daily", priority: 0.9 },
    { path: services_url, changefreq: "monthly", priority: 0.8 },
    { path: beta_signup_url, changefreq: "monthly", priority: 0.7 },
    { path: contact_us_url, changefreq: "monthly", priority: 0.7 },
    { path: privacy_policy_url, changefreq: "monthly", priority: 0.5 },
    { path: terms_of_service_url, changefreq: "monthly", priority: 0.5 }
  ].each do |page|
    xml.url do
      xml.loc page[:path]
      xml.changefreq page[:changefreq]
      xml.priority page[:priority]
    end
  end

  # Blog posts
  @blogs.each do |blog|
    xml.url do
      xml.loc blog_url(blog.slug)
      xml.lastmod blog.updated_at.to_date
      xml.changefreq "weekly"
      xml.priority 0.8
    end
  end

  # Case Studies
  @case_studies.each do |case_study|
    xml.url do
      xml.loc case_study_url(case_study)
      xml.lastmod case_study.updated_at.to_date
      xml.changefreq "monthly"
      xml.priority 0.8
    end
  end

  # Products
  @products.each do |product|
    xml.url do
      xml.loc product_url(product)
      xml.lastmod product.updated_at.to_date
      xml.changefreq "monthly"
      xml.priority 0.9
    end
  end

  # Solution pages (polymorphic landing pages)
  SolutionsController::SOLUTIONS.each_key do |slug|
    xml.url do
      xml.loc solution_url(slug)
      xml.changefreq "weekly"
      xml.priority 0.9
    end
  end
end
