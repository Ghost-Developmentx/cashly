class PlaidController < ApplicationController
  def create_link_token
    result = Banking::CreatePlaidLinkToken.call(user: current_user)

    if result.success?
      render json: { token: result.data[:link_token] }
    else
      render json: { error: result.error }, status: :unprocessable_entity
    end
  end

  def exchange_public_token
    result = Banking::ConnectBankAccount.call(
      user: current_user,
      params: { public_token: params[:public_token] }
    )

    if result.success?
      render json: { success: true }
    else
      render json: { success: false, error: result.error }, status: :unprocessable_entity
    end
  end

  def sync
    result = Banking::SyncBankAccounts.call(user: current_user)

    if result.success?
      redirect_to accounts_path, notice: "Successfully synced transactions."
    else
      redirect_to accounts_path, alert: result.error
    end
  end
end
