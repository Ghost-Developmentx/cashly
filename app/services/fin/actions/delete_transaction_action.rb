module Fin
  module Actions
    class DeleteTransactionAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "delete_transaction"
        raise "Transaction ID required" unless tool_result["transaction_id"].present?
      end

      def perform
        transaction = user.transactions.find_by(id: tool_result["transaction_id"])
        return error_response("Transaction not found") unless transaction
        return error_response("Cannot delete bank-synced transactions") if transaction.plaid_transaction_id.present?

        transaction_info = {
          description: transaction.description,
          amount: transaction.amount,
          account: transaction.account.name
        }

        if transaction.destroy
          success_response(
            "data" => {
              "deleted_transaction" => transaction_info
            },
            "message" => "Transaction deleted successfully!"
          )
        else
          error_response("Failed to delete transaction")
        end
      end
    end
  end
end
