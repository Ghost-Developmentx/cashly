class Fin::AccountsController < ApplicationController
  def create_link_token
    result = Banking::CreatePlaidLinkToken.call(user: current_user)
    render_operation_result(result)
  end

  def connect_account
    result = Banking::ConnectBankAccount.call(
      user: current_user,
      params: connection_params
    )

    render_operation_result(result)
  end

  def disconnect_account
    result = Banking::DisconnectBankAccount.call(
      user: current_user,
      account_id: params[:account_id]
    )

    render_operation_result(result)
  end

  def sync_accounts
    result = Banking::SyncBankAccounts.call(user: current_user)
    render_operation_result(result)
  end

  def account_status
    result = Banking::GetAccountStatus.call(user: current_user)
    render_operation_result(result)
  end

    private

  def connection_params
    params.permit(:public_token, :account_id, metadata: {})
  end
end
