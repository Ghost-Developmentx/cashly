module Billing
  class InvoicePresenter
    def initialize(invoice)
      @invoice = invoice
    end

    def as_json(options = {})
      {
        id: @invoice.id,
        client_name: @invoice.client_name,
        client_email: @invoice.client_email,
        amount: @invoice.amount.to_f,
        status: @invoice.status,
        issue_date: @invoice.issue_date.strftime("%Y-%m-%d"),
        due_date: @invoice.due_date.strftime("%Y-%m-%d"),
        invoice_number: @invoice.generate_invoice_number,
        description: @invoice.description,
        stripe_invoice_id: @invoice.stripe_invoice_id,
        currency: @invoice.currency,
        created_at: @invoice.created_at.iso8601,
        updated_at: @invoice.updated_at.iso8601,
        days_until_due: days_until_due,
        is_overdue: @invoice.overdue?
      }.merge(options)
    end

    private

    def days_until_due
      return 0 if @invoice.due_date.nil?
      (@invoice.due_date.to_date - Date.today).to_i
    end
  end
end
