module Fin
  class InvoiceService < BaseService
    def initialize(user)
      @user = user
      @connect_account = user.stripe_connect_account
      Stripe.api_key = ENV["STRIPE_SECRET_KEY"] if defined?(Stripe)
    end

    def create(invoice_data)
      log_info "Creating invoice with data: #{invoice_data.inspect}"

      # Check if Stripe Connect is set up
      unless @connect_account&.can_accept_payments?
        return error_response("Please set up Stripe Connect to create invoices")
      end

      # Build local invoice record
      invoice = build_invoice(invoice_data)

      unless invoice.valid?
        return error_response(invoice.errors.full_messages.join(", "))
      end

      # Create in Stripe first
      stripe_result = create_stripe_invoice(invoice_data)

      if stripe_result[:success]
        # Save local record with Stripe ID
        invoice.stripe_invoice_id = stripe_result[:stripe_invoice].id
        invoice.save!

        success_response(
          {
            invoice: InvoiceFormatter.format(invoice),
            invoice_id: invoice.id,
            platform_fee: stripe_result[:platform_fee],
            is_draft: true
          },
          "Invoice draft created! Review and send when ready."
        )
      else
        error_response("Failed to create invoice: #{stripe_result[:error]}")
      end
    rescue StandardError => e
      log_error "Failed to create invoice: #{e.message}"
      error_response("Failed to create invoice: #{e.message}")
    end

    def send_invoice(invoice_id)
      invoice = find_invoice(invoice_id)
      return error_response("Invoice not found") unless invoice
      return error_response("Invoice already sent") if %w[pending paid].include?(invoice.status)

      # Send via Stripe
      send_result = finalize_and_send_stripe_invoice(invoice)

      if send_result[:success]
        invoice.update!(
          status: "pending",
          sent_at: Time.current
        )

        # Include all the data the frontend expects
        success_response(
          {
            invoice: InvoiceFormatter.format(invoice),
            stripe_invoice_url: send_result[:hosted_invoice_url],
            hosted_invoice_url: send_result[:hosted_invoice_url],
            invoice_pdf: send_result[:invoice_pdf]
          },
          send_result[:message] || "Invoice sent successfully!"
        )
      else
        error_response(send_result[:error])
      end
    end

    def list(filters = {})
      # Could optionally fetch from Stripe API instead of local DB
      invoices = @user.invoices
      invoices = apply_filters(invoices, filters)
      invoices.order(created_at: :desc).limit(filters[:limit] || 20)
    end

    def sync_from_stripe(invoice_id)
      invoice = find_invoice(invoice_id)
      return error_response("Invoice not found") unless invoice

      begin
        stripe_invoice = Stripe::Invoice.retrieve(
          invoice.stripe_invoice_id,
          { stripe_account: @connect_account.stripe_account_id }
        )

        # Update local record with Stripe data
        invoice.update!(
          status: map_stripe_status(stripe_invoice.status),
          amount_paid: stripe_invoice.amount_paid / 100.0,
          payment_intent_id: stripe_invoice.payment_intent
        )

        success_response(
          { invoice: InvoiceFormatter.format(invoice) },
          "Invoice synced from Stripe"
        )
      rescue Stripe::StripeError => e
        error_response("Failed to sync: #{e.message}")
      end
    end

    private

    def build_invoice(invoice_data)
      @user.invoices.new(
        client_name: invoice_data["client_name"],
        client_email: invoice_data["client_email"],
        amount: invoice_data["amount"].to_f,
        description: invoice_data["description"],
        issue_date: Date.current,
        due_date: calculate_due_date(invoice_data["due_date"]),
        status: "draft",
        currency: invoice_data["currency"] || @user.currency || "USD"
      )
    end

    def create_stripe_invoice(invoice_data)
      begin
        amount = invoice_data["amount"].to_f
        platform_fee = (amount * @connect_account.platform_fee_percentage / 100).round(2)

        # Create or find a customer
        customer = find_or_create_stripe_customer(
          email: invoice_data["client_email"],
          name: invoice_data["client_name"]
        )

        stripe_invoice = Stripe::Invoice.create(
          {
            customer: customer.id,
            collection_method: "send_invoice",
            days_until_due: invoice_data["days_until_due"] || 30,
            description: invoice_data["description"],
            application_fee_amount: (platform_fee * 100).to_i,
            auto_advance: false,
            metadata: {
              cashly_user_id: @user.id,
              cashly_invoice_id: invoice_data["cashly_invoice_id"]
            }
          },
          { stripe_account: @connect_account.stripe_account_id }
        )

        Stripe::InvoiceItem.create(
          {
            customer: customer.id,
            invoice: stripe_invoice.id,
            amount: (amount * 100).to_i,
            currency: invoice_data["currency"] || "usd",
            description: invoice_data["description"]
          },
          { stripe_account: @connect_account.stripe_account_id }
        )

        # Refresh the invoice to get updated totals
        updated_invoice = Stripe::Invoice.retrieve(
          stripe_invoice.id,
          { stripe_account: @connect_account.stripe_account_id }
        )

        {
          success: true,
          stripe_invoice: updated_invoice,
          platform_fee: platform_fee,
          customer: customer
        }
      rescue Stripe::StripeError => e
        { success: false, error: e.message }
      end
    end

    def finalize_and_send_stripe_invoice(invoice)
      begin
        # Finalize
        finalized = Stripe::Invoice.finalize_invoice(
          invoice.stripe_invoice_id,
          {},
          { stripe_account: @connect_account.stripe_account_id }
        )

        # Send
        sent = Stripe::Invoice.send_invoice(
          invoice.stripe_invoice_id,
          {},
          { stripe_account: @connect_account.stripe_account_id }
        )

        {
          success: true,
          hosted_invoice_url: sent.hosted_invoice_url,
          invoice_pdf: sent.invoice_pdf,
          message: "Invoice sent successfully!"
        }
      rescue Stripe::StripeError => e
        { success: false, error: e.message }
      end
    end

    def delete(invoice_id)
      log_info "Deleting invoice with ID: #{invoice_id}"

      invoice = find_invoice(invoice_id)
      return error_response("Invoice not found") unless invoice

      # Only allow deletion of draft invoices
      unless invoice.status == "draft"
        return error_response("Only draft invoices can be deleted. This invoice is #{invoice.status}.")
      end

      # Store invoice info for response before deletion
      invoice_info = {
        id: invoice.id,
        client_name: invoice.client_name,
        amount: invoice.amount.to_f,
        invoice_number: invoice.generate_invoice_number,
        status: invoice.status
      }

      begin
        # Delete it from Stripe first if it exists
        if invoice.stripe_invoice_id.present? && @connect_account
          stripe_result = delete_stripe_invoice(invoice)

          # Log but don't fail if Stripe deletion fails
          unless stripe_result[:success]
            log_error "Stripe deletion failed: #{stripe_result[:error]}"
            # Continue with local deletion anyway
          end
        end

        # Delete it from a local database
        if invoice.destroy
          success_response(
            {
              deleted_invoice: invoice_info,
              invoice_id: invoice_id
            },
            "Invoice '#{invoice_info[:invoice_number]}' for #{invoice_info[:client_name]} has been deleted successfully."
          )
        else
          error_response("Failed to delete invoice from database: #{invoice.errors.full_messages.join(', ')}")
        end

      rescue StandardError => e
        log_error "Error during invoice deletion: #{e.message}"
        error_response("Failed to delete invoice: #{e.message}")
      end
    end

    def delete_stripe_invoice(invoice)
      begin
        log_info "Deleting Stripe invoice: #{invoice.stripe_invoice_id}"

        deleted_invoice = Stripe::Invoice.delete(
          invoice.stripe_invoice_id,
          {},
          { stripe_account: @connect_account.stripe_account_id }
        )

        log_info "Successfully deleted Stripe invoice: #{invoice.stripe_invoice_id}"

        {
          success: true,
          stripe_response: deleted_invoice
        }
      rescue Stripe::StripeError => e
        log_error "Stripe deletion failed: #{e.message}"

        # Common Stripe errors for invoice deletion
        case e.code
        when "invoice_not_found"
          log_info "Invoice not found in Stripe (may have been deleted already)"
          { success: true, message: "Invoice not found in Stripe (already deleted)" }
        when "invoice_finalized"
          { success: false, error: "Cannot delete finalized invoice from Stripe" }
        else
          { success: false, error: e.message }
        end
      end
    end

    def find_or_create_stripe_customer(email:, name:)
      customers = Stripe::Customer.search(
        { query: "email:'#{email}'" },
        { stripe_account: @connect_account.stripe_account_id }
      )

      if customers.data.any?
        customers.data.first
      else
        Stripe::Customer.create(
          { email: email, name: name },
          { stripe_account: @connect_account.stripe_account_id }
        )
      end
    end

    def map_stripe_status(stripe_status)
      case stripe_status
      when "draft" then "draft"
      when "open" then "pending"
      when "paid" then "paid"
      when "void" then "cancelled"
      else stripe_status
      end
    end

    def find_invoice(invoice_id)
      @user.invoices.find_by(id: invoice_id)
    end

    def calculate_due_date(due_date_str)
      return 30.days.from_now.to_date if due_date_str.blank?

      begin
        parsed_date = Date.parse(due_date_str.to_s)
        parsed_date < Date.current ? 30.days.from_now.to_date : parsed_date
      rescue ArgumentError
        30.days.from_now.to_date
      end
    end

    def apply_filters(invoices, filters)
      invoices = invoices.where(status: filters["status"]) if filters["status"].present?

      if filters["days"].present?
        start_date = filters["days"].to_i.days.ago
        invoices = invoices.where("created_at >= ?", start_date)
      end

      if filters["client_name"].present?
        invoices = invoices.where("client_name ILIKE ?", "%#{filters['client_name']}%")
      end

      invoices
    end
  end
end
