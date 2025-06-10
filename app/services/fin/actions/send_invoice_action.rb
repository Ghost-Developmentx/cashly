module Fin
  module Actions
    class SendInvoiceAction < BaseAction
      def validate!
        raise "Invoice ID required" unless tool_result["invoice_id"].present?
      end

      def perform
        result = Billing::SendInvoice.call(
          user: user,
          invoice_id: tool_result["invoice_id"]
        )

        if result.success?
          {
            "type" => "invoice_send_success",
            "success" => true,
            "data" => {
              "invoice" => result.data[:invoice],
              "stripe_invoice_url" => result.data[:stripe_invoice_url],
              "hosted_invoice_url" => result.data[:hosted_invoice_url],
              "invoice_pdf" => result.data[:invoice_pdf]
            },
            "message" => result.data[:message],
            "silent" => false
          }
        else
          {
            "type" => "invoice_send_error",
            "success" => false,
            "error" => result.error,
            "message" => result.error
          }
        end
      end
    end
  end
end
