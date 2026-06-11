module Api
  module V1
    # Public, read-only JSON API for agents and integrations.
    # Inherits ActionController::API (not ApplicationController) to skip the
    # modern-browser gate, CSRF, and view layout that would block non-browser
    # clients. Only exposes already-public published/active content.
    class BaseController < ActionController::API
      before_action :set_discovery_headers

      rescue_from ActiveRecord::RecordNotFound, with: :not_found

      private

      def set_discovery_headers
        response.headers["Link"] =
          '<https://www.revnous.com/api/v1/openapi.json>; rel="service-desc", ' \
          '<https://www.revnous.com/llms.txt>; rel="describedby"'
      end

      def not_found
        render json: { error: "not_found" }, status: :not_found
      end
    end
  end
end
