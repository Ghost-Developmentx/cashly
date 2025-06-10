module Banking
  class DeleteTransaction < BaseOperation
    attr_reader :user, :transaction_id

    validates :user, presence: true
    validates :transaction_id, presence: true

    def initialize(user:, transaction_id:)
      @user = user
      @transaction_id = transaction_id
    end

    def execute
      transaction = find_transaction
      validate_can_delete!(transaction)

      transaction_info = extract_transaction_info(transaction)

      transaction.destroy!

      success(
        deleted_transaction: transaction_info,
        message: "Transaction '#{transaction_info[:description]}' deleted successfully"
      )
    end

    private

    def find_transaction
      user.transactions.find(transaction_id)
    end

    def validate_can_delete!(transaction)
      if transaction.plaid_transaction_id.present?
        raise StandardError, "Cannot delete transactions imported from your bank."
      end
    end

    def extract_transaction_info(transaction)
      {
        id: transaction.id,
        description: transaction.description,
        amount: transaction.amount.to_f,
        account: transaction.account.name,
        date: transaction.date.strftime("%Y-%m-%d")
      }
    end
  end
end
