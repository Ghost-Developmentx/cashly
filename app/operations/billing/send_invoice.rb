module Billing
  class SendInvoice < BaseOperation
    attr_reader :user, :invoice_id

    validates :user, presence: true
    validates :invoice_id, presence: true

    def initialize(user:, invoice_id:)
      @user = user
      @invoice_id = invoice_id
    end

    def execute
      invoice = find_invoice
      validate_can_send!(invoice)

      stripe_result = finalize_and_send(invoice)

      if stripe_result[:success]
        invoice.update!(
          status: 'pending',
          sent_at: Time.current
        )

        success(
          invoice: present_invoice(invoice),
          stripe_invoice_url: stripe_result[:hosted_invoice_url],
          hosted_invoice_url: stripe_result[:hosted_invoice_url],
          invoice_pdf: stripe_result[:invoice_pdf],
          message: stripe_result[:message] || "Invoice sent successfully!"
        )
      else
        failure(stripe_result[:error])
      end
    end

    private

    def find_invoice
      user.invoices.find(invoice_id)
    end

    def validate_can_send!(invoice)
      if %w[pending paid].include?(invoice.status)
        raise StandardError, "Invoice already sent"
      end

      unless invoice.stripe_invoice_id.present?
        raise StandardError, "Invoice not properly created"
      end
    end

    def finalize_and_send(invoice)
      service = StripeConnectService.new(user)
      service.finalize_and_send_invoice(invoice)
    end

    def present_invoice(invoice)
      Billing::InvoicePresenter.new(invoice).as_json
    end
  end
end