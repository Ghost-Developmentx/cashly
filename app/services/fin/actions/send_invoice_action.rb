module Fin
  module Actions
    class SendInvoiceAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "send_invoice"
        raise "Invoice ID required" unless tool_result["invoice_id"].present?
      end

      def perform
        invoice_id = tool_result["invoice_id"]
        invoice = user.invoices.find_by(id: invoice_id)

        return error_response("Invoice not found") unless invoice
        return error_response("Invoice already sent") if invoice.status != "draft"
        return error_response("No Stripe invoice ID") unless invoice.stripe_invoice_id

        service = StripeConnectService.new(user)
        send_result = service.finalize_and_send_invoice(invoice)

        if send_result[:success]
          invoice.update!(status: "pending")

          success_response(
            "data" => {
              "invoice" => format_invoice(invoice),
              "stripe_invoice_url" => send_result[:hosted_invoice_url],
              "invoice_pdf" => send_result[:invoice_pdf]
            },
            "message" => send_result[:message] || "Invoice sent successfully!",
            "invoice_url" => send_result[:hosted_invoice_url]
          )
        else
          error_response(send_result[:error])
        end
      end

      private

      def format_invoice(invoice)
        {
          id: invoice.id,
          client_name: invoice.client_name,
          amount: invoice.amount.to_f,
          status: invoice.status,
          invoice_number: invoice.generate_invoice_number
        }
      end
    end
  end
end
