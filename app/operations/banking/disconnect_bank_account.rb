module Banking
  class DisconnectBankAccount < BaseOperation
    attr_reader :user, :account_id

    validates :user, presence: true
    validates :account_id, presence: true

    def initialize(user:, account_id:)
      @user = user
      @account_id = account_id
    end

    def execute
      account = find_account
      validate_can_disconnect!(account)

      account_name = account.name

      # Remove Plaid connection if exists
      remove_plaid_connection(account) if account.plaid_account_id.present?

      # Delete the account and associated data
      account.destroy!

      success(
        message: "#{account_name} has been disconnected successfully"
      )
    end

    private

    def find_account
      user.accounts.find(account_id)
    end

    def validate_can_disconnect!(account)
      # Add any business rules for disconnection here
      # For example, checking if there are pending transactions
    end

    def remove_plaid_connection(account)
      # In a production app, you might want to call Plaid's item/remove endpoint
      # For now, we'll just remove the local reference
      plaid_token = user.plaid_tokens.find_by(item_id: account.plaid_account_id)
      plaid_token&.destroy
    rescue StandardError => e
      Rails.logger.error "Error removing Plaid connection: #{e.message}"
      # Continue with disconnection even if Plaid removal fails
    end
  end
end