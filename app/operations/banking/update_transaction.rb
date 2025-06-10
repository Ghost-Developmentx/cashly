module Banking
  class UpdateTransaction < BaseOperation
    attr_reader :user, :transaction_id, :params

    validates :user, presence: true
    validates :transaction_id, presence: true

    def initialize(user:, transaction_id:, params:)
      @user = user
      @transaction_id = transaction_id
      @params = params
    end

    def execute
      transaction = find_transaction
      validate_can_edit!(transaction)

      old_values = capture_old_values(transaction)

      update_transaction(transaction)

      success(
        transaction: present_transaction(transaction),
        changes: calculate_changes(old_values, transaction),
        message: "Transaction updated successfully"
      )
    end

    private

    def find_transaction
      user.transactions.find(transaction_id)
    end

    def validate_can_edit!(transaction)
      if transaction.plaid_transaction_id.present?
        raise StandardError, "Cannot edit transactions imported from your bank. These are automatically synced."
      end
    end

    def capture_old_values(transaction)
      {
        amount: transaction.amount,
        description: transaction.description,
        category: transaction.category&.name,
        date: transaction.date
      }
    end

    def update_transaction(transaction)
      updates = prepare_updates(params)
      transaction.update!(updates)
    end

    def prepare_updates(params)
      updates = params.dup

      # Handle category update
      if updates[:category].present?
        category = Category.find_or_create_by(name: updates[:category])
        updates[:category_id] = category.id
        updates.delete(:category)
      end

      # Only include allowed attributes
      updates.slice(:amount, :description, :date, :category_id, :recurring, :notes)
    end

    def calculate_changes(old_values, transaction)
      changes = {}

      changes[:amount] = {
        from: old_values[:amount].to_f,
        to: transaction.amount.to_f
      } if old_values[:amount] != transaction.amount

      changes[:description] = {
        from: old_values[:description],
        to: transaction.description
      } if old_values[:description] != transaction.description

      changes[:category] = {
        from: old_values[:category],
        to: transaction.category&.name
      } if old_values[:category] != transaction.category&.name

      changes[:date] = {
        from: old_values[:date].strftime("%Y-%m-%d"),
        to: transaction.date.strftime("%Y-%m-%d")
      } if old_values[:date] != transaction.date

      changes
    end

    def present_transaction(transaction)
      Banking::TransactionPresenter.new(transaction).as_json
    end
  end
end
