class Fin::AccountsController < ApplicationController
    def create_link_token
      # Create Plaid link token for account connection initiated by Fin
      plaid_service = PlaidService.new(current_user)
      link_token = plaid_service.create_link_token

      if link_token
        render json: {
          success: true,
          link_token: link_token,
          message: "Link token created successfully"
        }
      else
        render json: {
          success: false,
          error: "Failed to create Plaid link token"
        }, status: :unprocessable_entity
      end
    end

    def connect_account
      # Handle account connection from Fin chat
      public_token = params[:public_token]
      metadata = params[:metadata] || {}

      if public_token.blank?
        render json: {
          success: false,
          error: "Missing public token"
        }, status: :bad_request
        return
      end

      plaid_service = PlaidService.new(current_user)
      item_id = plaid_service.exchange_public_token(public_token)

      if item_id.present?
        # Sync initial transactions
        plaid_service.sync_transactions

        # Get updated account information
        accounts = current_user.accounts.includes(:transactions)

        render json: {
          success: true,
          message: "Bank account connected successfully!",
          accounts: accounts.map { |account|
            {
              id: account.id,
              name: account.name,
              account_type: account.account_type,
              balance: account.balance,
              institution: account.institution,
              transaction_count: account.transactions.count
            }
          }
        }
      else
        render json: {
          success: false,
          error: "Failed to connect bank account"
        }, status: :unprocessable_entity
      end
    end

    def disconnect_account
      # Handle account disconnection from Fin chat
      account_id = params[:account_id]
      account = current_user.accounts.find_by(id: account_id)

      unless account
        render json: {
          success: false,
          error: "Account not found"
        }, status: :not_found
        return
      end

      # Store account name for response
      account_name = account.name

      begin
        # Remove Plaid connection if exists
        if account.plaid_account_id.present?
          # Note: In a real implementation, you might want to call Plaid's
          # item/remove endpoint to properly disconnect from Plaid
        end

        # Delete the account and associated data
        account.destroy

        render json: {
          success: true,
          message: "#{account_name} has been disconnected successfully"
        }
      rescue => e
        render json: {
          success: false,
          error: "Failed to disconnect account: #{e.message}"
        }, status: :unprocessable_entity
      end
    end

    def sync_accounts
      # Manual sync triggered by Fin
      begin
        plaid_service = PlaidService.new(current_user)
        success = plaid_service.sync_transactions

        if success
          accounts = current_user.accounts.includes(:transactions)

          render json: {
            success: true,
            message: "Accounts synced successfully",
            accounts: accounts.map { |account|
              {
                id: account.id,
                name: account.name,
                account_type: account.account_type,
                balance: account.balance,
                institution: account.institution,
                transaction_count: account.transactions.count,
                last_synced: account.last_synced
              }
            }
          }
        else
          render json: {
            success: false,
            error: "Failed to sync accounts"
          }, status: :unprocessable_entity
        end
      rescue => e
        render json: {
          success: false,
          error: "Sync failed: #{e.message}"
        }, status: :unprocessable_entity
      end
    end

    def account_status
      # Get current account status for Fin
      accounts = current_user.accounts.includes(:transactions)

      render json: {
        account_count: accounts.count,
        total_balance: accounts.sum(:balance),
        accounts: accounts.map { |account|
          {
            id: account.id,
            name: account.name,
            account_type: account.account_type,
            balance: account.balance,
            institution: account.institution,
            transaction_count: account.transactions.count,
            last_synced: account.last_synced,
            plaid_connected: account.plaid_account_id.present?
          }
        },
        has_plaid_connection: current_user.plaid_tokens.exists?
      }
    end

    private

    def account_params
      params.permit(:public_token, :account_id, metadata: {})
  end
end
