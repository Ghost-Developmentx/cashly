module Fin
  module Actions
    class SendInvoiceAction < BaseAction
      def validate!
        raise "Invoice ID required" unless tool_result["invoice_id"].present?
      end

      def perform
        service = Fin::InvoiceService.new(user)
        result = service.send_invoice(tool_result["invoice_id"])

        Rails.logger.info "[SendInvoiceAction] Service result: #{result.inspect}"

        if result[:success]
          # Return the full data structure that the frontend expects
          {
            "type" => "invoice_send_success",
            "success" => true,
            "data" => {
              "invoice" => result[:invoice],
              "stripe_invoice_url" => result[:stripe_invoice_url],
              "hosted_invoice_url" => result[:stripe_invoice_url],
              "invoice_pdf" => result[:invoice_pdf]
            },
            "message" => result[:message],
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
