class StripeWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    # Retrieve event from Stripe
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, ENV["STRIPE_WEBHOOK_SECRET"]
      )
    rescue JSON::ParserError => e
      render json: { error: "Invalid payload" }, status: :bad_request
      return
    rescue Stripe::SignatureVerificationError => e
      render json: { error: "Invalid signature" }, status: :bad_request
      return
    end

    # Handle the event
    case event.type
    when "invoice.payment_succeeded"
      handle_payment_succeeded(event.data.object)
    when "invoice.payment_failed"
      handle_payment_failed(event.data.object)
    when "customer.subscription.deleted"
      handle_subscription_deleted(event.data.object)
    else
      # type code here
    end

    render json: { status: "success" }
  end

  private

  def handle_payment_succeeded(stripe_invoice)
    # Find our invoice by Stripe invoice ID
    invoice = Invoice.find_by(stripe_invoice_id: stripe_invoice.id)
    return unless invoice

    # Update our invoice
    invoice.update(
      status: "paid",
      payment_status: "paid",
      payment_method: stripe_invoice.payment_intent&.payment_method_types&.first
    )

    # Send confirmation email
    InvoiceMailer.payment_confirmation(invoice).deliver_later
  end

  def handle_payment_failed(stripe_invoice)
    # Find our invoice by Stripe invoice ID
    invoice = Invoice.find_by(stripe_invoice_id: stripe_invoice.id)
    return unless invoice

    # Update our invoice
    invoice.update(
      payment_status: "failed",
      last_payment_attempt: Time.current
    )

    # Send failed payment notification
    InvoiceMailer.payment_failed(invoice).deliver_later
  end

  def handle_subscription_deleted(subscription)
    # Find our invoice by Stripe subscription ID
    invoice = Invoice.find_by(stripe_subscription_id: subscription.id)
    return unless invoice

    # Update our invoice to remove recurring info
    invoice.update(
      recurring: false,
      stripe_subscription_id: nil,
      next_payment_date: nil
    )
  end
end
