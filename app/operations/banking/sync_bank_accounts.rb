module Banking
  class SyncBankAccounts < BaseOperation
    attr_reader :user

    validates :user, presence: true

    def initialize(user:)
      @user = user
    end

    def execute
      unless user.plaid_tokens.exists?
        return failure("No bank accounts connected")
      end

      plaid_service = PlaidService.new(user)

      # Sync accounts and transactions
      sync_result = perform_sync(plaid_service)

      if sync_result[:success]
        accounts = user.accounts.includes(:transactions)

        success(
          accounts: present_accounts(accounts),
          message: "Accounts synced successfully",
          transactions_synced: sync_result[:transaction_count],
          new_transactions: sync_result[:new_transactions]
        )
      else
        failure("Failed to sync accounts: #{sync_result[:error]}")
      end
    end

    private

    def perform_sync(plaid_service)
      Rails.logger.info "[SyncBankAccounts] Starting sync for user #{user.id}"

      initial_transaction_count = user.transactions.count

      begin
        success = plaid_service.sync_transactions

        if success
          final_transaction_count = user.transactions.count
          new_transactions = final_transaction_count - initial_transaction_count

          {
            success: true,
            transaction_count: final_transaction_count,
            new_transactions: new_transactions
          }
        else
          { success: false, error: "Sync failed" }
        end
      rescue StandardError => e
        Rails.logger.error "[SyncBankAccounts] Error: #{e.message}"
        { success: false, error: e.message }
      end
    end

    def present_accounts(accounts)
      accounts.map do |account|
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
      end
    end
  end
end