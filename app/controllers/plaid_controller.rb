class PlaidController < ApplicationController
  before_action :authenticate_user!
  rescue_from StandardError, with: :handle_error

  def create_link_token
    plaid_service = PlaidService.new(current_user)
    link_token = plaid_service.create_link_token

    if link_token
      render json: { token: link_token }
    else
      render json: { error: "Failed to create plaid link token" }, status: :unprocessable_content
    end
  end

  def exchange_public_token
    public_token = params[:public_token]

    if public_token.blank?
      render json: { success: false, error: "Missing public token" }, status: :bad_request
      return
    end

    plaid_service = PlaidService.new(current_user)
    item_id = plaid_service.exchange_public_token(public_token)

    if item_id.present?
      # Sync initial transactions
      plaid_service.sync_transactions

      render json: { success: true }
    else
      render json: { success: false, error: "Failed to exchange public token" }, status: :unprocessable_content
    end
  end

  def sync
    plaid_service = PlaidService.new(current_user)
    success = plaid_service.sync_transactions

    if success
      redirect_to accounts_path, notice: "Successfully synced transactions."
    else
      redirect_to accounts_path, alert: "Failed to sync transactions."
    end
  end

  private

  def handle_error(exception)
    Rails.logger.error "Plaid API Error: #{exception.message}"
    render json: { success: false, error: "An error occurred with the Plaid API. Please try again later." },
           status: :internal_server_error
  end
end
