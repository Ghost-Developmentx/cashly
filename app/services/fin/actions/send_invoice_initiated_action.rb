module Fin
  module Actions
    class SendInvoiceInitiatedAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "send_invoice_initiated"
        raise "Invoice ID required" unless tool_result["invoice_id"].present?
      end

      def perform
        manager = Fin::InvoiceService.new(user)
        result = manager.send_invoice(tool_result["invoice_id"])

        if result[:success]
          {
            "type" => "invoice_send_success",
            "success" => true,
            "data" => result[:data],
            "message" => result[:message],
            "silent" => true
          }
        else
          {
            "type" => "invoice_send_error",
            "success" => false,
            "error" => result[:error],
            "message" => result[:error]
          }
        end
      end
    end
  end
end