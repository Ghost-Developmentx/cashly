module Fin
  module Actions
    class SendInvoiceAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "send_invoice"
        raise "Invoice ID required" unless tool_result["invoice_id"].present?
      end

      def perform
        manager = Fin::InvoiceService.new(user)
        result = manager.send_invoice(tool_result["invoice_id"])

        if result[:success]
          {
            "type" => "send_invoice",
            "success" => true,
            "data" => result,
            "silent" => true

          }
        else
          {
            "type" => "send_invoice_error",
            "success" => false,
            "error" => result[:error],
            "message" => result[:error]
          }
        end
      end
    end
  end
end
