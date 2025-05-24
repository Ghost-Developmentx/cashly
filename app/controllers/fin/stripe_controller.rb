module Fin
  class StripeController < ApplicationController
    def connect
      api_key = params[:api_key]

      if api_key.blank?
        render json: { success: false, error: "API key is required" }, status: :bad_request
        return
      end

      # Connect Stripe using an existing Integration model
      integration = Integration.connect_stripe(current_user, api_key)

      if integration
        render json: {
          success: true,
          message: "Stripe account connected successfully!"
        }
      else
        render json: {
          success: false,
          error: "Failed to connect Stripe account. Please check your API key."
        }, status: :unprocessable_entity
      end
    end

    def disconnect
      integration = current_user.integrations.active.by_provider("stripe").first

      if integration&.disconnect
        render json: { success: true, message: "Stripe account disconnected" }
      else
        render json: { success: false, error: "Failed to disconnect" }, status: :unprocessable_entity
      end
    end

    def status
      integration = current_user.integrations.active.by_provider("stripe").first

      render json: {
        connected: integration.present?,
        last_used: integration&.last_used_at,
        status: integration&.status || "not_connected"
      }
    end
  end
end