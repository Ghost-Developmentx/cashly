class PlaidController < ApplicationController
  before_action :authenticate_user!

  def create_link_token
    plaid_service = PlaidService.new(current_user)
    link_token = plaid_service.create_link_token

    render json: { token: link_token }
  end

  def exchange_public_token
    public_token = params[:public_token]

    plaid_service = PlaidService.new(current_user)
    item_id = plaid_service.exchange_public_token(public_token)

    if item_id.present?
      # Sync initial transactions
      plaid_service.sync_transactions

      render json: { success: true }
    else
      render json: { success: false }, status: :unprocessable_content
    end
  end

  def sync
    plaid_service = PlaidService.new(current_user)
    success = plaid_service.sync_transactions

    if success
      redirect_to account_path, notice: "Successfully synced transactions."
    else
      redirect_to account_path, notice: "Failed to sync transactions."
    end
  end
end
