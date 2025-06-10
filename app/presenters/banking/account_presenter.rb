module Banking
  class AccountPresenter
    def initialize(account)
      @account = account
    end

    def as_json(options = {})
      {
        id: @account.id,
        name: @account.name,
        account_type: @account.account_type,
        balance: @account.balance.to_f,
        formatted_balance: format_balance,
        institution: @account.institution,
        last_synced: @account.last_synced&.iso8601,
        plaid_linked: @account.plaid_linked?,
        transaction_count: @account.transactions.count,
        created_at: @account.created_at.iso8601
      }.merge(options)
    end

    private

    def format_balance
      currency = @account.user.currency || "USD"
      balance = Banking::AccountBalance.new(@account.balance, nil, currency)
      balance.format
    end
  end
end
