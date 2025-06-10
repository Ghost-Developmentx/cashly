module Fin
  module Actions
    class DeleteInvoiceAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "delete_invoice"
        raise "Invoice ID required" unless tool_result["invoice_id"].present?
      end

      def perform
        result = Billing::DeleteInvoice.call(
          user: user,
          invoice_id: tool_result["invoice_id"]
        )

        if result.success?
          {
            "type" => "invoice_delete_success",
            "success" => true,
            "data" => {
              "deleted_invoice" => result.data[:deleted_invoice],
              "stripe_deleted" => true
            },
            "message" => result.data[:message],
            "silent" => false
          }
        else
          {
            "type" => "invoice_delete_error",
            "success" => false,
            "error" => result.error,
            "message" => result.error
          }
        end
      end
    end
  end
end
