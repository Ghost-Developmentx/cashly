module Billing
  class DeleteInvoice < BaseOperation
    attr_reader :user, :invoice_id

    validates :user, presence: true
    validates :invoice_id, presence: true

    def initialize(user:, invoice_id:)
      @user = user
      @invoice_id = invoice_id
    end

    def execute
      invoice = find_invoice
      validate_can_delete!(invoice)

      invoice_info = extract_invoice_info(invoice)

      # Delete from Stripe first if exists
      if invoice.stripe_invoice_id.present? && user.stripe_connect_account
        delete_from_stripe(invoice)
      end

      # Delete from database
      if invoice.destroy
        success(
          deleted_invoice: invoice_info,
          invoice_id: invoice_id,
          message: "Invoice '#{invoice_info[:invoice_number]}' for #{invoice_info[:client_name]} has been deleted successfully."
        )
      else
        failure("Failed to delete invoice")
      end
    end

    private

    def find_invoice
      user.invoices.find(invoice_id)
    end

    def validate_can_delete!(invoice)
      unless invoice.status == "draft"
        raise StandardError, "Only draft invoices can be deleted. This invoice is #{invoice.status}."
      end
    end

    def extract_invoice_info(invoice)
      {
        id: invoice.id,
        client_name: invoice.client_name,
        amount: invoice.amount.to_f,
        invoice_number: invoice.generate_invoice_number,
        status: invoice.status
      }
    end

    def delete_from_stripe(invoice)
      Stripe::Invoice.delete(
        invoice.stripe_invoice_id,
        {},
        { stripe_account: user.stripe_connect_account.stripe_account_id }
      )
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe deletion failed: #{e.message}"
      # Continue with local deletion even if Stripe fails
    end
  end
end