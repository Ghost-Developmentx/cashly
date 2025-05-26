module Fin
  module Actions
    class MarkInvoicePaidAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "mark_invoice_paid"
        raise "Invoice ID required" unless tool_result["invoice_id"].present?
      end

      def perform
        invoice = user.invoices.find_by(id: tool_result["invoice_id"])
        return error_response("Invoice not found") unless invoice

        invoice.mark_as_paid

        success_response(
          "data" => {
            "invoice" => format_invoice(invoice)
          },
          "message" => "Invoice marked as paid"
        )
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
