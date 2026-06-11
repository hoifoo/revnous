module Api
  module V1
    class ProductsController < BaseController
      def index
        @products = Product.active.ordered
      end

      def show
        @product = Product.active.find(params[:id])
      end
    end
  end
end
