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

        # Add debug logging to see what we're returning
        invoices.each do |invoice|
          log_info "DEBUG: Invoice ##{invoice[:id]} - #{invoice[:client_name]} - Status: #{invoice[:status]}"
        end

        # Return the correct action type for the frontend
        {
          "type" => "show_invoices",
          "success" => true,
          "data" => { "invoices" => invoices },
          "message" => "Found #{invoices.length} invoice#{invoices.length == 1 ? '' : 's'}"
        }
      end

      private

      def fetch_and_format_invoices(filters)
        invoices = user.invoices

        # Apply filters if specified, otherwise show ALL invoices
        invoices = invoices.where(status: filters["status"]) if filters["status"].present?
        invoices = invoices.where("client_name ILIKE ?", "%#{filters['client_name']}%") if filters["client_name"].present?

        # Add invoice ID filtering for deletion/specific lookup
        invoices = invoices.where(id: filters["invoice_id"]) if filters["invoice_id"].present?
        invoices = invoices.where(id: filters["id"]) if filters["id"].present?

        # Add date filter if specified
        if filters["days"].present?
          start_date = filters["days"].to_i.days.ago
          invoices = invoices.where("created_at >= ?", start_date)
        end

        # Order by most recent first and include ALL statuses
        formatted_invoices = invoices.order(created_at: :desc).limit(50).map do |invoice|
          {
            id: invoice.id,
            client_name: invoice.client_name,
            client_email: invoice.client_email,
            amount: invoice.amount.to_f,
            status: invoice.status, # Make sure this reflects current status
            issue_date: invoice.issue_date.strftime("%Y-%m-%d"),
            due_date: invoice.due_date.strftime("%Y-%m-%d"),
            invoice_number: invoice.generate_invoice_number,
            description: invoice.description,
            stripe_invoice_id: invoice.stripe_invoice_id,
            created_at: invoice.created_at.iso8601,
            updated_at: invoice.updated_at.iso8601
          }
        end

        # Debug logging
        log_info "DEBUG: Fetched #{formatted_invoices.length} invoices from database"
        formatted_invoices.each do |invoice|
          log_info "DEBUG: Raw Invoice ##{invoice[:id]} - #{invoice[:client_name]} - Status: #{invoice[:status]}"
        end

        formatted_invoices
      end
    end
  end
end
