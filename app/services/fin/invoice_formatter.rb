module Fin
  class InvoiceFormatter
    def self.format(invoice)
      {
        id: invoice.id,
        client_name: invoice.client_name,
        client_email: invoice.client_email,
        amount: invoice.amount.to_f,
        status: invoice.status,
        issue_date: invoice.issue_date.strftime("%Y-%m-%d"),
        due_date: invoice.due_date.strftime("%Y-%m-%d"),
        invoice_number: invoice.generate_invoice_number,
        description: invoice.description,
        stripe_invoice_id: invoice.stripe_invoice_id,
        currency: invoice.currency,
        created_at: invoice.created_at.iso8601
      }
    end

    def self.format_collection(invoices)
      invoices.map { |invoice| format(invoice) }
    end
  end
end
