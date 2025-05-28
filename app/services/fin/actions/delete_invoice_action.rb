module Fin
  module Actions
    class DeleteInvoiceAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "delete_invoice"
        raise "Invoice ID required" unless tool_result["invoice_id"].present?
      end

      def perform
        service = Fin::InvoiceService.new(user)
        result = service.send(:delete, tool_result["invoice_id"])

        Rails.logger.info "[DeleteInvoiceAction] Service result: #{result.inspect}"

        if result[:success]
          {
            "type" => "invoice_delete_success",
            "success" => true,
            "data" => {
              "deleted_invoice" => result[:deleted_invoice],
              "stripe_deleted" => result[:stripe_deleted]
            },
            "message" => result[:message],
            "silent" => false
          }
        else
          {
            "type" => "invoice_delete_error",
            "success" => false,
            "error" => result[:error],
            "message" => result[:error]
          }
        end
      end
    end
  end
end
