module Banking
  class AccountBalance < Shared::Money
    attr_reader :available_balance, :pending_balance

    def initialize(current_balance, available_balance = nil, currency = "USD")
      super(current_balance, currency)
      @available_balance = available_balance ? Shared::Money.new(available_balance, currency) : nil
      @pending_balance = calculate_pending_balance
    end

    def has_pending_transactions?
      available_balance && amount_cents != available_balance.amount_cents
    end

    private

    def calculate_pending_balance
      return Shared::Money.new(0, currency) unless available_balance
      Shared::Money.new((amount_cents - available_balance.amount_cents) / 100.0, currency)
    end
  end
end