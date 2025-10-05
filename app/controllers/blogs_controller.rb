class BlogsController < ApplicationController
  def index
    @blogs = Blog.published.page(params[:page]).per(9)
    @featured_blog = Blog.published.featured.first
    @categories = Blog.published.pluck(:category).compact.uniq.sort
    @special_offer = SpecialOffer.for_page('blogs').first
  end

  def show
    @blog = Blog.find_by!(slug: params[:id])
    @related_blogs = Blog.published
                         .where(category: @blog.category)
                         .where.not(id: @blog.id)
                         .limit(3)

    if @related_blogs.count < 3
      @related_blogs = Blog.published.where.not(id: @blog.id).limit(3)
    end
  end
end
