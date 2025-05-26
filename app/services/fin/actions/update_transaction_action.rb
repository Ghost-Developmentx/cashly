module Fin
  module Actions
    class UpdateTransactionAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "update_transaction"
        raise "Transaction ID required" unless tool_result["transaction_id"].present?
        raise "Updates required" unless tool_result["updates"].present?
      end

      def perform
        transaction = user.transactions.find_by(id: tool_result["transaction_id"])
        return error_response("Transaction not found") unless transaction
        return error_response("Cannot edit bank-synced transactions") if transaction.plaid_transaction_id.present?

        updates = prepare_updates(tool_result["updates"])

        if transaction.update(updates)
          success_response(
            "data" => {
              "transaction" => format_transaction(transaction)
            },
            "message" => "Transaction updated successfully!"
          )
        else
          error_response(transaction.errors.full_messages.join(", "))
        end
      end

      private

      def prepare_updates(updates)
        prepared = updates.dup

        if prepared["category"]
          category = Category.find_or_create_by(name: prepared["category"])
          prepared["category_id"] = category.id
          prepared.delete("category")
        end

        prepared
      end

      def format_transaction(transaction)
        {
          id: transaction.id,
          amount: transaction.amount.to_f,
          description: transaction.description,
          date: transaction.date.strftime("%Y-%m-%d"),
          category: transaction.category&.name || "Uncategorized",
          account: transaction.account.name
        }
      end
    end
  end
end
