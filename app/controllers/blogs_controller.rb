class BlogsController < ApplicationController
  def index
    @page_title = "Blog - Revnous"
    @page_description = "Expert insights, tips, and strategies for Shopify merchants to optimize revenue and grow their business."
    @blogs = Blog.published.page(params[:page]).per(9)
    @featured_blog = Blog.published.featured.first
    @categories = Blog.published.pluck(:category).compact.uniq.sort
    @special_offer = SpecialOffer.for_page("blogs").first
  end

  def show
    @blog = Blog.find_by!(slug: params[:id])
    @page_title = @blog.seo_title
    @page_description = @blog.seo_description
    @page_og_type = "article"
    @page_og_image = og_image_for(@blog)
    @canonical_url = @blog.canonical_url_override.presence || blog_url(@blog.slug)
    @page_keywords = @blog.keywords

    @related_blogs = Blog.published
                         .where(category: @blog.category)
                         .where.not(id: @blog.id)
                         .limit(3)
                         .to_a

    if @related_blogs.length < 3
      @related_blogs = Blog.published.where.not(id: @blog.id).limit(3).to_a
    end

    respond_to do |format|
      format.html
      format.md { render_blog_markdown }
    end
  end

  private

  def render_blog_markdown
    markdown = +"# #{@blog.title}\n\n"
    markdown << "**Author:** #{@blog.author&.display_name || 'Revnous'}\n"
    markdown << "**Published:** #{@blog.published_at&.strftime('%B %d, %Y') || @blog.created_at.strftime('%B %d, %Y')}\n"
    markdown << "**Updated:** #{@blog.updated_at.strftime('%B %d, %Y')}\n\n"
    markdown << "---\n\n"
    markdown << "#{@blog.excerpt}\n\n" if @blog.excerpt.present?
    markdown << "---\n\n"
    markdown << "#{sanitized_blog_content}\n\n"
    markdown << "---\n\n"
    markdown << "**Keywords:** #{@blog.keywords}\n" if @blog.keywords.present?
    markdown << "**Canonical URL:** #{@canonical_url}\n\n" if @canonical_url.present?
    markdown << "**Source:** #{blog_url(@blog.slug)}\n"

    render plain: markdown, content_type: "text/markdown; charset=utf-8"
  end

  def sanitized_blog_content
    if @blog.body.present?
      ActionController::Base.helpers.strip_tags(@blog.body).gsub(/\s+/, " ")
    elsif @blog.content.present?
      ActionController::Base.helpers.strip_tags(@blog.content.to_s).gsub(/\s+/, " ")
    else
      ""
    end
  end

  def og_image_for(blog)
    if blog.og_image.attached?
      blog.og_image_url
    elsif blog.image.attached?
      blog.cover_photo_url
    else
      helpers.asset_url("logo.png")
    end
  end
end
