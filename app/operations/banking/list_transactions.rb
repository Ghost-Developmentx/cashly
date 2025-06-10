module Banking
  class ListTransactions < BaseOperation
    attr_reader :user, :filters

    validates :user, presence: true

    def initialize(user:, filters: {})
      @user = user
      @filters = filters
    end

    def execute
      transactions = TransactionQuery.new(user.transactions)
                                     .with_filters(filters)
                                     .execute

      success(
        transactions: present_transactions(transactions),
        summary: calculate_summary(transactions)
      )
    end

    private

    def present_transactions(transactions)
      transactions.map { |t| Banking::TransactionPresenter.new(t).as_json }
    end

    def calculate_summary(transactions)
      # Create arrays for calculations
      all_transactions = transactions.to_a

      total_income = all_transactions.select { |t| t.amount > 0 }.sum(&:amount)
      total_expenses = all_transactions.select { |t| t.amount < 0 }.sum(&:amount).abs

      # Category breakdown
      category_spending = all_transactions
                            .select { |t| t.amount < 0 }
                            .group_by { |t| t.category&.name || "Uncategorized" }
                            .transform_values { |txns| txns.sum(&:amount).abs }

      {
        count: all_transactions.size,
        total_income: total_income,
        total_expenses: total_expenses,
        net_change: total_income - total_expenses,
        date_range: determine_date_range(all_transactions),
        category_breakdown: category_spending,
        filters_applied: filters
      }
    end

    def determine_date_range(transactions)
      return "No transactions" if transactions.empty?

      dates = transactions.map(&:date)
      start_date = dates.min
      end_date = dates.max

      "#{start_date.strftime('%b %d, %Y')} to #{end_date.strftime('%b %d, %Y')}"
    end
  end
end
