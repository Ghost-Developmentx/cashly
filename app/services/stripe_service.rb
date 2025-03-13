class StripeService
  def initialize(user)
    @user = user
    Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
  end

  # Create or retrieve a stripe customer for user
  def create_or_retrieve_customer
    if @user.stripe_customer_id.present?
      # Return existing customer
      Stripe::Customer.retrieve(@user.stripe_customer_id)
    else
      # Create new customer
      customer = Stripe::Customer.create(
      email: @user.email,
      name: @user.full_name,
      metadata: {
        user_id: @user.id
      }
      )

      # Save customer ID to user record
      @user.update(stripe_customer_id: customer.id)

      customer
    end
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe error: #{e.message}"
    nil
  end

  # Create a stripe invoice
  def create_invoice(invoice)
    # Ensure we have customer
    customer = create_or_retrieve_customer
    return nil unless customer

    # Create invoice item
    item = Stripe::InvoiceItem.create({
      customer: customer.id,
      amount: (invoice.amount * 100.0).to_i,
      currency: invoice.currency || "usd",
      description: "Invoice ##{invoice.id} - #{invoice.client_name}"
                                      })

    # Now create invoice in stripe
    stripe_invoice = Stripe::Invoice.create({
                                              customer: customer.id,
                                              collection_method: "send_invoice",
                                              days_until_due: (invoice.due_date.to_date - Date.today).to_i,
                                              description: invoice.description,
                                              metadata: {
                                                invoice_id: invoice.id
                                              }
                                            })

    # Update our invoice with the stripe ID
    invoice.update(
      stripe_invoice_id: stripe_invoice.id,
      payment_status: "awaiting_payment",
    )

    stripe_invoice
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe invoice creation error: #{e.message}"
    nil
  end

  # Finalize and send the invoice
  def finalize_and_send_invoice(invoice)
    return false unless invoice.stripe_invoice_id.present?

    # Finalize the invoice in Stripe
    stripe_invoice = Stripe::Invoice.finalize_invoice(invoice.stripe_invoice_id)

    # Send the invoice
    Stripe::Invoice.send_invoice(invoice.stripe_invoice_id)

    # Update our invoice
    invoice.update(
      status: "pending",
      payment_status: "awaiting_payment"
    )

    true
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe finalize/send error: #{e.message}"
    false
  end

  # Check payment status of an invoice
  def check_payment_status(invoice)
    return nil unless invoice.stripe_invoice_id.present?

    stripe_invoice = Stripe::Invoice.retrieve(invoice.stripe_invoice_id)

    # Map Stripe status to our status
    status = case stripe_invoice.status
    when "paid"
      "paid"
    when "uncollectible"
      "failed"
    when "draft"
      "draft"
    else
      "awaiting_payment"
    end

    # Update our invoice
    invoice.update(
      payment_status: status,
      status: status == "paid" ? "paid" : invoice.status
    )

    status
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe status check error: #{e.message}"
    nil
  end

  # Create a recurring invoice subscription
  def create_recurring_invoice(invoice, interval, interval_count)
    return nil unless invoice.client_email.present?

    # Ensure we have a customer
    customer = create_or_retrieve_customer
    return nil unless customer

    # Create a product for this invoice
    product = Stripe::Product.create(
      name: "Invoice ##{invoice.id} - #{invoice.client_name} (Recurring)",
      metadata: {
        invoice_id: invoice.id
      }
    )

    # Create a price for the product
    price = Stripe::Price.create(
      product: product.id,
      unit_amount: (invoice.amount * 100).to_i,
      currency: invoice.currency || "usd",
      recurring: {
        interval: interval, # 'day', 'week', 'month', or 'year'
        interval_count: interval_count
      }
    )

    # Create a subscription
    subscription = Stripe::Subscription.create(
      customer: customer.id,
      items: [
        { price: price.id }
      ],
      metadata: {
        invoice_id: invoice.id
      }
    )

    # Update our invoice with recurring info
    invoice.update(
      recurring: true,
      stripe_subscription_id: subscription.id,
      recurring_interval: interval,
      recurring_period: interval_count,
      next_payment_date: Date.today + get_next_interval_date(interval, interval_count)
    )

    subscription
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe recurring invoice error: #{e.message}"
    nil
  end

  # Cancel a recurring invoice
  def cancel_recurring_invoice(invoice)
    return false unless invoice.stripe_subscription_id.present?

    # Cancel the subscription
    Stripe::Subscription.cancel(invoice.stripe_subscription_id)

    # Update our invoice
    invoice.update(
      recurring: false,
      stripe_subscription_id: nil,
      next_payment_date: nil
    )

    true
  rescue Stripe::StripeError => e
    Rails.logger.error "Stripe cancel recurring error: #{e.message}"
    false
  end

  private

  def get_next_interval_date(interval, count)
    case interval
    when "day"
      count.days
    when "week"
      count.weeks
    when "month"
      count.months
    when "year"
      count.years
    else
      30.days # Default to monthly
    end
  end
end
