module Banking
  class GetAccountStatus < BaseOperation
    attr_reader :user

    validates :user, presence: true

    def initialize(user:)
      @user = user
    end

    def execute
      accounts = user.accounts.includes(:transactions)

      success(
        account_count: accounts.count,
        total_balance: calculate_total_balance(accounts),
        accounts: present_accounts(accounts),
        has_plaid_connection: user.plaid_tokens.exists?,
        last_sync: last_sync_time,
        sync_status: determine_sync_status
      )
    end

    private

    def calculate_total_balance(accounts)
      accounts.sum(:balance)
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
          plaid_connected: account.plaid_account_id.present?,
          created_at: account.created_at.iso8601
        }
      end
    end

    def last_sync_time
      user.accounts.maximum(:last_synced)
    end

    def determine_sync_status
      return "not_connected" unless user.plaid_tokens.exists?

      last_sync = last_sync_time
      return "never_synced" if last_sync.nil?

      if last_sync > 1.hour.ago
        "up_to_date"
      elsif last_sync > 1.day.ago
        "recent"
      else
        "outdated"
      end
    end
  end
end
