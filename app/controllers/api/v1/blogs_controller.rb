module Api
  module V1
    class BlogsController < BaseController
      def index
        @blogs = Blog.published.page(params[:page]).per(20)
      end

      def show
        @blog = Blog.published.find_by!(slug: params[:slug])
      end
    end
  end
end
