module Fin
  module Actions
    class CategorizeTransactionsAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "categorize_transactions"
      end

      def perform
        uncategorized = user.transactions.where(category_id: nil).limit(50)

        if uncategorized.any?
          CategorizeTransactionsJob.perform_later(user.id, uncategorized.pluck(:id))

          success_response(
            "data" => {
              "count" => uncategorized.count
            },
            "message" => "Started categorizing transactions in the background!"
          )
        else
          success_response(
            "data" => { "count" => 0 },
            "message" => "All transactions are already categorized!"
          )
        end
      end
    end
  end
end
