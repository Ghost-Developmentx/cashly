module Fin
  module Actions
    class SendInvoiceReminderAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "send_invoice_reminder"
        raise "Invoice ID required" unless tool_result["invoice_id"].present?
      end

      def perform
        invoice = user.invoices.find_by(id: tool_result["invoice_id"])
        return error_response("Invoice not found") unless invoice
        return error_response("Can only send reminders for pending invoices") unless invoice.status == "pending"

        invoice.send_reminder

        success_response(
          "data" => {
            "invoice_id" => invoice.id
          },
          "message" => "Payment reminder sent to #{invoice.client_name}"
        )
      end
    end
  end
end
