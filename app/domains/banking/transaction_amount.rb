module Banking
  class TransactionAmount < Shared::Money
    def income?
      amount_cents > 0
    end

    def expense?
      amount_cents < 0
    end

    def absolute
      Shared::Money.new(amount_cents.abs / 100.0, currency)
    end

    def type
      income? ? 'income' : 'expense'
    end
  end
end
