module Banking
  class ConnectBankAccount < BaseOperation
    attr_reader :user, :form

    validates :user, presence: true

    def initialize(user:, params:)
      @user = user
      @form = PlaidConnectionForm.new(params)
    end

    def execute
      validate_form!

      plaid_service = PlaidService.new(user)
      item_id = plaid_service.exchange_public_token(form.public_token)

      if item_id.present?
        # Sync initial transactions
        sync_result = sync_initial_data(plaid_service)

        # Get updated account information
        accounts = fetch_updated_accounts

        success(
          accounts: present_accounts(accounts),
          message: "Bank account connected successfully!",
          synced_transactions: sync_result[:transaction_count]
        )
      else
        failure("Failed to connect bank account")
      end
    end

    private

    def validate_form!
      unless form.valid?
        raise ActiveRecord::RecordInvalid.new(form)
      end
    end

    def sync_initial_data(plaid_service)
      Rails.logger.info "[ConnectBankAccount] Starting initial sync"

      success = plaid_service.sync_transactions
      transaction_count = user.transactions.where("created_at >= ?", 5.minutes.ago).count

      { success: success, transaction_count: transaction_count }
    end

    def fetch_updated_accounts
      user.accounts.includes(:transactions).order(:name)
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
          last_synced: account.last_synced&.iso8601
        }
      end
    end
  end
end
