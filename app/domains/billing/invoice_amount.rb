module Billing
  class InvoiceAmount < Shared::Money
    def platform_fee(percentage)
      fee_amount = (amount_cents * percentage / 100.0).round
      Shared::Money.new(fee_amount / 100.0, currency)
    end

    def days_until_due_from(days)
      days.to_i.days.from_now.to_date
    end
  end
end
