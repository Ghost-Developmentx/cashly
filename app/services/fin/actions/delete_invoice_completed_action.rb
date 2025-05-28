module Fin
  module Actions
    class DeleteInvoiceCompletedAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "delete_invoice_completed"
      end

      def perform
        {
          "type" => "invoice_delete_success",
          "success" => true,
          "data" => {
            "deleted_invoice" => tool_result["deleted_invoice"],
            "stripe_deleted" => tool_result["stripe_deleted"]
          },
          "message" => tool_result["message"] || "Invoice deleted successfully!",
          "silent" => false
        }
      end
    end
  end
end
