module Api
  module V1
    class BaseController < ApplicationController
      include Clerk::Authenticatable

      before_action :authenticate_request!

      private

      def authenticate_request!
        # Check for internal API key first (for service-to-service calls)
        if request.headers["X-Internal-Api-Key"] == ENV["INTERNAL_API_KEY"]
          # Find user from params
          @current_user = User.find_by(id: params[:user_id])
          return if @current_user
        end

        # Otherwise use Clerk authentication
        require_clerk_session!
      end

      def render_success(data, meta = {})
        render json: {
          success: true,
          data: data,
          meta: meta
        }
      end

      def render_error(message, status = :unprocessable_entity)
        render json: {
          success: false,
          error: message
        }, status: status
      end

      def pagination_params
        {
          page: params[:page]&.to_i || 1,
          limit: [params[:limit]&.to_i || 100, 1000].min,
          offset: params[:offset]&.to_i || 0
        }
      end
    end
  end
end