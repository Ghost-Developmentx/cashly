module Fin
  class BaseController < ApplicationController
    before_action :ensure_user_ready

    private

    def ensure_user_ready
      # Any Fin-specific setup
    end

    def render_success(data = {}, message = nil)
      response = { success: true, **data }
      response[:message] = message if message
      render json: response
    end

    def render_error(error, status = :unprocessable_entity)
      render json: {
        success: false,
        error: error,
        message: "I encountered an issue: #{error}"
      }, status: status
    end
  end
end
