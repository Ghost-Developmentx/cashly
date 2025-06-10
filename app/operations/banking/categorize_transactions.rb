module Banking
  class CategorizeTransactions < BaseOperation
    attr_reader :user, :transaction_ids

    validates :user, presence: true

    def initialize(user:, transaction_ids: nil)
      @user = user
      @transaction_ids = transaction_ids
    end

    def execute
      transactions = find_uncategorized_transactions

      if transactions.any?
        # Schedule background job
        CategorizeTransactionsJob.perform_later(user.id, transactions.pluck(:id))

        success(
          count: transactions.count,
          message: "Categorizing #{transactions.count} transactions in the background"
        )
      else
        success(
          count: 0,
          message: "All transactions are already categorized!"
        )
      end
    end

    private

    def find_uncategorized_transactions
      scope = user.transactions.where(category_id: nil)

      if transaction_ids.present?
        scope = scope.where(id: transaction_ids)
      end

      scope.limit(50)
    end
  end
end