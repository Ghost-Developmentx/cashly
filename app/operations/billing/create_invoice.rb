module Billing
  class CreateInvoice < BaseOperation
    attr_reader :user, :form

    validates :user, presence: true

    def initialize(user:, params:)
      @user = user
      @form = InvoiceForm.new(params)
    end

    def execute
      validate_form!
      validate_stripe_connection!

      invoice = create_local_invoice
      stripe_result = create_stripe_invoice(invoice)

      if stripe_result[:success]
        invoice.update!(stripe_invoice_id: stripe_result[:stripe_invoice].id)
        success(
          invoice: present_invoice(invoice),
          invoice_id: invoice.id,
          platform_fee: stripe_result[:platform_fee],
          is_draft: true,
          message: "Invoice draft created! Review and send when ready."
        )
      else
        invoice.destroy
        failure("Failed to create invoice: #{stripe_result[:error]}")
      end
    end

    private

    def validate_form!
      unless form.valid?
        raise ActiveRecord::RecordInvalid.new(form)
      end
    end

    def validate_stripe_connection!
      unless user.stripe_connect_account&.can_accept_payments?
        raise StandardError, "Please set up Stripe Connect to create invoices"
      end
    end

    def create_local_invoice
      user.invoices.create!(form.to_invoice_attributes)
    end

    def create_stripe_invoice(invoice)
      service = StripeConnectService.new(user)
      service.create_invoice_with_fee(
        form.to_stripe_attributes.merge(
          cashly_invoice_id: invoice.id
        )
      )
    end

    def present_invoice(invoice)
      Billing::InvoicePresenter.new(invoice).as_json
    end
  end
end
