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
    @blog[:author] = params.dig(:blog, :author).presence

    if @blog.save
      redirect_to admin_blogs_path, notice: "Blog post created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @blog[:author] = params.dig(:blog, :author).presence
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
    permitted = %i[title author_id published_at category
                   excerpt body featured featured_on_home image og_image
                   meta_title meta_description spacing canonical_url_override]
    permitted << :slug if action_name == 'create'
    params.require(:blog).permit(*permitted, product_ids: [], keywords: [])
  end
end
