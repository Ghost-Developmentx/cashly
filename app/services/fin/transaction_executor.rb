module Fin
  class TransactionExecutor < BaseService
    def initialize(user)
      @user = user
    end

    def create(transaction_data)
      account = find_account(transaction_data)
      return error_response("Account not found") unless account

      transaction = build_transaction(account, transaction_data)

      if transaction.save
        success_response(
          { transaction: format_for_response(transaction) },
          "Transaction created successfully"
        )
      else
        error_response(transaction.errors.full_messages.join(", "))
      end
    rescue StandardError => e
      log_error "Failed to create transaction: #{e.message}"
      error_response("Failed to create transaction: #{e.message}")
    end

    def update(transaction_id, updates)
      transaction = @user.transactions.find_by(id: transaction_id)
      return error_response("Transaction not found") unless transaction
      return error_response("Cannot edit bank-synced transactions") if transaction.plaid_transaction_id.present?

      prepare_updates!(updates)

      if transaction.update(updates)
        success_response(
          { transaction: format_for_response(transaction) },
          "Transaction updated successfully"
        )
      else
        error_response(transaction.errors.full_messages.join(", "))
      end
    rescue StandardError => e
      log_error "Failed to update transaction: #{e.message}"
      error_response("Failed to update transaction: #{e.message}")
    end

    def delete(transaction_id)
      transaction = @user.transactions.find_by(id: transaction_id)
      return error_response("Transaction not found") unless transaction
      return error_response("Cannot delete bank-synced transactions") if transaction.plaid_transaction_id.present?

      transaction_info = {
        description: transaction.description,
        amount: transaction.amount,
        account: transaction.account.name
      }

      if transaction.destroy
        success_response(
          { deleted_transaction: transaction_info },
          "Transaction deleted successfully"
        )
      else
        error_response("Failed to delete transaction")
      end
    rescue StandardError => e
      log_error "Failed to delete transaction: #{e.message}"
      error_response("Failed to delete transaction: #{e.message}")
    end

    def categorize_bulk
      uncategorized_transactions = @user.transactions.where(category_id: nil).limit(50)

      if uncategorized_transactions.any?
        CategorizeTransactionsJob.perform_later(@user.id, uncategorized_transactions.pluck(:id))
        success_response(
          { count: uncategorized_transactions.count },
          "Categorizing #{uncategorized_transactions.count} transactions in the background"
        )
      else
        success_response(
          { count: 0 },
          "All transactions are already categorized!"
        )
      end
    end

    private

    def find_account(transaction_data)
      if transaction_data["account_id"]
        @user.accounts.find_by(id: transaction_data["account_id"])
      elsif transaction_data["account_name"]
        @user.accounts.where("name ILIKE ?", "%#{transaction_data['account_name']}%").first
      else
        @user.accounts.first
      end
    end

    def build_transaction(account, transaction_data)
      transaction = account.transactions.new(
        amount: transaction_data["amount"],
        description: transaction_data["description"],
        date: transaction_data["date"] || Date.current,
        recurring: transaction_data["recurring"] || false
      )

      if transaction_data["category"]
        category = Category.find_or_create_by(name: transaction_data["category"])
        transaction.category = category
      end

      transaction
    end

    def prepare_updates!(updates)
      if updates["category"]
        category = Category.find_or_create_by(name: updates["category"])
        updates["category_id"] = category.id
        updates.delete("category")
      end
    end

    def format_for_response(transaction)
      {
        id: transaction.id,
        amount: transaction.amount.to_f,
        description: transaction.description,
        date: transaction.date.strftime("%Y-%m-%d"),
        category: transaction.category&.name || "Uncategorized",
        account: transaction.account.name,
        recurring: transaction.recurring || false,
        editable: transaction.plaid_transaction_id.blank?
      }
    end
  end
end
