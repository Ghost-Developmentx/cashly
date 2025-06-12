module Billing
  class ProcessStripeWebhook < BaseOperation
    attr_reader :payload, :signature

    validates :payload, presence: true
    validates :signature, presence: true

    def initialize(payload:, signature:)
      @payload = payload
      @signature = signature
    end

    def execute
      event = construct_event

      case event.type
      when "account.updated", "account.application.deauthorized"
        process_account_event(event)
      when "invoice.payment_succeeded"
        process_invoice_payment(event)
      else
        Rails.logger.info "Unhandled Stripe webhook: #{event.type}"
      end

      success(event_type: event.type)
    rescue Stripe::SignatureVerificationError => e
      failure("Invalid signature")
    rescue JSON::ParserError => e
      failure("Invalid payload")
    rescue StandardError => e
      Rails.logger.error "Webhook processing error: #{e.message}"
      failure("Processing error")
    end

    private

    def construct_event
      endpoint_secret = ENV["STRIPE_CONNECT_WEBHOOK_SECRET"]

      Stripe::Webhook.construct_event(
        payload, signature, endpoint_secret
      )
    end

    def process_account_event(event)
      account_id = event.data.object.id
      connect_account = StripeConnectAccount.find_by(stripe_account_id: account_id)

      if connect_account
        service = StripeConnectService.new(connect_account.user)
        service.process_account_webhook(event)
      end
    end

    def process_invoice_payment(event)
      invoice = event.data.object
      cashly_invoice_id = invoice.metadata&.dig("cashly_invoice_id")

      return unless cashly_invoice_id

      # Find user and mark invoice as paid
      user = User.joins(:stripe_connect_account)
                 .where(stripe_connect_accounts: { stripe_account_id: invoice.account })
                 .first

      if user && cashly_invoice_id
        invoice_record = user.invoices.find_by(id: cashly_invoice_id)
        invoice_record&.mark_as_paid

        # Log platform fee earned
        platform_fee = invoice.application_fee_amount.to_f / 100
        Rails.logger.info "Platform fee earned: $#{platform_fee} from invoice #{cashly_invoice_id}"
      end
    end
  end
end
