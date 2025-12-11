class Admin::BlogsController < Admin::BaseController
  before_action :set_blog, only: [ :edit, :update, :destroy ]

  def index
    @blogs = Blog.order(created_at: :desc).page(params[:page]).per(20)
  end

  def new
    @blog = Blog.new
  end

  def create
    @blog = Blog.new(blog_params)

    if @blog.save
      redirect_to admin_blogs_path, notice: "Blog post created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @blog.update(blog_params)
      redirect_to admin_blogs_path, notice: "Blog post updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @blog.destroy
    redirect_to admin_blogs_path, notice: "Blog post deleted successfully."
  end

  private

  def set_blog
    @blog = Blog.find(params[:id])
  end

  def blog_params
    params.require(:blog).permit(
      :title, :author, :published_at, :category,
      :excerpt, :content, :slug, :featured, :featured_on_home, :image,
      :meta_title, :meta_description,
      product_ids: []
    )
  end
end
