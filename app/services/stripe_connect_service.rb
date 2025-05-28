class StripeConnectService
  include Rails.application.routes.url_helpers

  def initialize(user)
    @user = user
    Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
  end

  def create_express_account(country: "US", business_type: "individual")
    begin
      # Create an Express account
      account = Stripe::Account.create({
                                         type: "express",
                                         country: country,
                                         email: @user.email,
                                         business_type: business_type,
                                         metadata: {
                                           user_id: @user.id,
                                           platform: "cashly"
                                         }
                                       })

      # Save to a database
      connect_account = @user.create_stripe_connect_account!(
        stripe_account_id: account.id,
        account_type: "express",
        country: country,
        email: @user.email,
        business_type: business_type,
        status: "pending",
        platform_fee_percentage: 2.9
      )

      # Sync initial data
      connect_account.sync_from_stripe!

      # Create onboarding link
      onboarding_link = create_onboarding_link(account.id)

      {
        success: true,
        account: connect_account,
        onboarding_url: onboarding_link.url,
        message: "Stripe Connect account created successfully"
      }

    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe Connect account creation failed: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  def create_onboarding_link(account_id = nil)
    account_id ||= @user.stripe_connect_account&.stripe_account_id
    return nil unless account_id

    Stripe::AccountLink.create({
                                 account: account_id,
                                 refresh_url: stripe_connect_onboarding_refresh_url,
                                 return_url: stripe_connect_onboarding_success_url,
                                 type: "account_onboarding"
                               })
  end

  def create_dashboard_link
    connect_account = @user.stripe_connect_account

    unless connect_account&.stripe_account_id.present?
      return {
        success: false,
        error: "No Stripe Connect account found"
      }
    end

    begin
      login_link = Stripe::Account.create_login_link(
        connect_account.stripe_account_id,
      )
      message = case connect_account.status
                when "active"
                  "Opening your Stripe dashboard..."
                when "pending"
                  "Opening your Stripe dashboard to complete setup requirements..."
                when "rejected"
                  "Opening your Stripe dashboard to address account requirements..."
                else
                  "Opening your Stripe dashboard..."
                end

      {
        success: true,
        dashboard_url: login_link.url,
        message: message,
        account_status: connect_account.status
      }
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe dashboard link creation failed: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  def process_account_webhook(event)
    account = event.data.object
    connect_account = StripeConnectAccount.find_by(stripe_account_id: account.id)

    return unless connect_account

    case event.type
    when "account.updated"
      connect_account.sync_from_stripe!

      # Notify the user if status changed significantly
      if connect_account.saved_change_to_status?
        notify_user_of_status_change(connect_account)
      end

    when "account.application.deauthorized"
      connect_account.update!(status: "inactive")

    else
      # type code here
    end
  end


  def create_invoice_with_fee(invoice_params)
    connect_account = @user.stripe_connect_account
    return { success: false, error: "No Stripe Connect account found" } unless connect_account&.can_accept_payments?

    begin
      Rails.logger.info "Creating Stripe invoice with params: #{invoice_params.inspect}"

      # Calculate platform fee
      amount = invoice_params[:amount].to_f
      platform_fee = (amount * connect_account.platform_fee_percentage / 100).round(2)

      # Validate days_until_due
      days_until_due = invoice_params[:days_until_due].to_i
      if days_until_due <= 0
        Rails.logger.warn "Invalid days_until_due: #{days_until_due}, using 30 days"
        days_until_due = 30
      end

      # Create or find a customer for the client
      customer = create_or_find_customer(
        email: invoice_params[:client_email],
        name: invoice_params[:client_name],
        connected_account: connect_account.stripe_account_id
      )

      Rails.logger.info "Customer created/found: #{customer.id}"

      # Create invoice item
      invoice_item = Stripe::InvoiceItem.create({
                                                  customer: customer.id,
                                                  amount: (amount * 100).to_i, # Convert to cents
                                                  currency: invoice_params[:currency] || "usd",
                                                  description: invoice_params[:description]
                                                }, {
                                                  stripe_account: connect_account.stripe_account_id
                                                })

      Rails.logger.info "Invoice item created: #{invoice_item.id}"

      # Create invoice
      stripe_invoice = Stripe::Invoice.create({
                                                customer: customer.id,
                                                collection_method: "send_invoice",
                                                days_until_due: days_until_due,
                                                description: invoice_params[:description],
                                                application_fee_amount: (platform_fee * 100).to_i, # Platform fee in cents
                                                metadata: {
                                                  cashly_user_id: @user.id,
                                                  cashly_invoice_id: invoice_params[:cashly_invoice_id],
                                                  platform_fee_percentage: connect_account.platform_fee_percentage
                                                }
                                              }, {
                                                stripe_account: connect_account.stripe_account_id
                                              })

      Rails.logger.info "Stripe invoice created: #{stripe_invoice.id}"

      {
        success: true,
        stripe_invoice: stripe_invoice,  # This is the actual Stripe::Invoice object
        platform_fee: platform_fee,
        customer: customer,
        message: "Invoice created successfully with #{connect_account.platform_fee_percentage}% platform fee"
      }

    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe Connect invoice creation failed: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  def finalize_and_send_invoice(invoice)
    connect_account = @user.stripe_connect_account
    return { success: false, error: "No Stripe Connect account" } unless connect_account

    begin
      Rails.logger.info "Finalizing and sending invoice: #{invoice.stripe_invoice_id}"

      # Step 1: Finalize the invoice (makes it ready to send)
      finalized_invoice = Stripe::Invoice.finalize_invoice(
        invoice.stripe_invoice_id,
        {},
        { stripe_account: connect_account.stripe_account_id }
      )

      Rails.logger.info "Invoice finalized: #{finalized_invoice.id}"

      # Step 2: Send the invoice to the client
      sent_invoice = Stripe::Invoice.send_invoice(
        invoice.stripe_invoice_id,
        {},
        { stripe_account: connect_account.stripe_account_id }
      )

      Rails.logger.info "Invoice sent successfully. Hosted URL: #{sent_invoice.hosted_invoice_url}"

      # Make sure we're returning the payment URL
      {
        success: true,
        hosted_invoice_url: sent_invoice.hosted_invoice_url,
        invoice_pdf: sent_invoice.invoice_pdf,
        message: "Invoice sent successfully to #{invoice.client_email}"
      }

    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to finalize/send invoice: #{e.message}"
      {
        success: false,
        error: "Failed to send invoice: #{e.message}"
      }
    end
  end



  private

  def create_or_find_customer(email:, name:, connected_account:)
    # Search for existing customer
    customers = Stripe::Customer.search({
                                          query: "email:'#{email}'"
                                        }, {
                                          stripe_account: connected_account
                                        })

    if customers.data.any?
      customers.data.first
    else
      Stripe::Customer.create({
                                email: email,
                                name: name
                              }, {
                                stripe_account: connected_account
                              })
    end
    end

  def notify_user_of_status_change(connect_account)
    case connect_account.status
    when "active"
      # User can now accept payments
      UserMailer.stripe_connect_activated(@user).deliver_later
    when "rejected"
      # The Account was rejected
      UserMailer.stripe_connect_rejected(@user, connect_account.status_reason).deliver_later
    else
      # type code here
    end
  end

    def stripe_connect_onboarding_refresh_url
      if Rails.env.production?
        "https://app.cashly.com/api/fin/stripe_connect/onboarding_refresh"
      else
        # Point to Rails backend (localhost:3000)
        "http://localhost:3000/fin/stripe_connect/onboarding_refresh"
      end
    end

  def stripe_connect_onboarding_success_url
    if Rails.env.production?
      "https://app.cashly.com/stripe/connect/onboarding/success"
    else
      "http://localhost:3000/fin/stripe_connect/onboarding_success"
    end
  end
end
