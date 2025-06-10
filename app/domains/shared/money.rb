module Shared
  class Money
    include Comparable

    attr_reader :amount_cents, :currency

    def initialize(amount, currency = "USD")
      @amount_cents = parse_amount(amount)
      @currency = currency.upcase
    end

    def amount
      BigDecimal(amount_cents) / 100
    end

    def to_f
      amount.to_f
    end

    def to_s
      amount.to_s("F")
    end

    def to_cents
      amount_cents
    end

    def format
      # Simple formatting - you can enhance this with Money gem later
      case currency
      when "USD" then "$#{'%.2f' % amount}"
      when "EUR" then "€#{'%.2f' % amount}"
      when "GBP" then "£#{'%.2f' % amount}"
      else "#{currency} #{'%.2f' % amount}"
      end
    end

    def +(other)
      raise ArgumentError unless other.is_a?(Money) && other.currency == currency
      Money.new((amount_cents + other.amount_cents) / 100.0, currency)
    end

    def -(other)
      raise ArgumentError unless other.is_a?(Money) && other.currency == currency
      Money.new((amount_cents - other.amount_cents) / 100.0, currency)
    end

    def *(multiplier)
      Money.new((amount_cents * multiplier) / 100.0, currency)
    end

    def /(divisor)
      Money.new(amount_cents / divisor / 100.0, currency)
    end

    def <=>(other)
      return nil unless other.is_a?(Money) && other.currency == currency
      amount_cents <=> other.amount_cents
    end

    def ==(other)
      other.is_a?(Money) &&
        other.amount_cents == amount_cents &&
        other.currency == currency
    end

    private

    def parse_amount(value)
      case value
      when Integer then value * 100
      when Float, BigDecimal then (BigDecimal(value.to_s) * 100).to_i
      when String then (BigDecimal(value) * 100).to_i
      when Money then value.amount_cents
      else raise ArgumentError, "Cannot parse amount from #{value.class}"
      end
    end
  end
end
