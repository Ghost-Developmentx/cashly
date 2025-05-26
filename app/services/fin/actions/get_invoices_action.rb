module Fin
  module Actions
    class GetInvoicesAction < BaseAction
      def perform
        invoices = if tool_result["invoices"].present?
                     tool_result["invoices"]
                   else
                     filters = tool_result["filters"] || {}
                     fetch_and_format_invoices(filters)
                   end

        return error_response("No invoices found") unless invoices.any?

        log_info "Found #{invoices.length} invoices"

        success_response(
          "data" => { "invoices" => invoices }
        )
      end

      private

      def fetch_and_format_invoices(filters)
        invoices = user.invoices
        invoices = invoices.where(status: filters["status"]) if filters["status"].present?
        invoices = invoices.where("client_name ILIKE ?", "%#{filters['client_name']}%") if filters["client_name"].present?

        invoices.order(created_at: :desc).limit(20).map do |invoice|
          {
            id: invoice.id,
            client_name: invoice.client_name,
            client_email: invoice.client_email,
            amount: invoice.amount.to_f,
            status: invoice.status,
            issue_date: invoice.issue_date.strftime("%Y-%m-%d"),
            due_date: invoice.due_date.strftime("%Y-%m-%d"),
            invoice_number: invoice.generate_invoice_number,
            description: invoice.description
          }
        end
      end
    end
  end
end
