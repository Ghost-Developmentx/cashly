module Fin
  module Actions
    class CreateTransactionAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "create_transaction"
        raise "Transaction data required" unless tool_result["transaction"].present?
      end

      def perform
        transaction_data = tool_result["transaction"]

        # Find an account
        account = find_account(transaction_data)
        return error_response("Account not found") unless account

        # Create transaction
        transaction = account.transactions.build(
          amount: transaction_data["amount"],
          description: transaction_data["description"],
          date: transaction_data["date"] || Date.current,
          recurring: transaction_data["recurring"] || false
        )

        # Handle category
        if transaction_data["category"].present?
          category = Category.find_or_create_by(name: transaction_data["category"])
          transaction.category = category
        end

        if transaction.save
          success_response(
            "data" => {
              "transaction" => format_transaction(transaction)
            },
            "message" => "Transaction created successfully!"
          )
        else
          error_response(transaction.errors.full_messages.join(", "))
        end
      end

      private

      def find_account(transaction_data)
        if transaction_data["account_id"]
          user.accounts.find_by(id: transaction_data["account_id"])
        elsif transaction_data["account_name"]
          user.accounts.where("name ILIKE ?", "%#{transaction_data['account_name']}%").first
        else
          user.accounts.first
        end
      end

      def format_transaction(transaction)
        {
          id: transaction.id,
          amount: transaction.amount.to_f,
          description: transaction.description,
          date: transaction.date.strftime("%Y-%m-%d"),
          category: transaction.category&.name || "Uncategorized",
          account: transaction.account.name,
          recurring: transaction.recurring || false
        }
      end
    end
  end
end
