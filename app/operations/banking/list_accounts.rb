module Banking
  class ListAccounts < BaseOperation
    attr_reader :user

    validates :user, presence: true

    def initialize(user:)
      @user = user
    end

    def execute
      accounts = user.accounts.includes(:transactions).order(:name)

      success(
        accounts: present_accounts(accounts),
        summary: build_summary(accounts)
      )
    end

    private

    def present_accounts(accounts)
      accounts.map do |account|
        Banking::AccountPresenter.new(account).as_json
      end
    end

    def build_summary(accounts)
      {
        total_count: accounts.count,
        total_balance: accounts.sum(:balance),
        by_type: accounts.group(:account_type).sum(:balance),
        plaid_connected_count: accounts.where.not(plaid_account_id: nil).count
      }
    end
  end
end