module Fin
  module Actions
    class SendInvoiceInitiatedAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "send_invoice_initiated"
        raise "Invoice ID required" unless tool_result["invoice_id"].present?
      end

      def perform
        service = Fin::InvoiceService.new(user)
        result = service.send_invoice(tool_result["invoice_id"])

        if result[:success]
          {
            "type" => "invoice_send_success",
            "success" => true,
            "data" => {
              "invoice" => result[:invoice],
              "stripe_invoice_url" => result[:stripe_invoice_url],
              "hosted_invoice_url" => result[:hosted_invoice_url],
              "invoice_pdf" => result[:invoice_pdf]
            },
            "silent" => false
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
