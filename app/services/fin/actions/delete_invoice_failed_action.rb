module Fin
  module Actions
    class DeleteInvoiceFailedAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "delete_invoice_failed"
      end

      def perform
        {
          "type" => "invoice_delete_error",
          "success" => false,
          "error" => tool_result["error"],
          "message" => tool_result["message"] || "Failed to delete invoice",
          "silent" => false
        }
      end
    end
  end
end
