module Fin
  class InvoiceManager < BaseService
    def initialize(user)
      @user = user
    end

    def create(invoice_data)
      log_info "Creating invoice with data: #{invoice_data.inspect}"

      invoice = build_invoice(invoice_data)

      if invoice.valid?
        invoice.save!
        handle_stripe_integration(invoice, invoice_data)
      else
        log_error "Invoice validation failed: #{invoice.errors.full_messages.join(', ')}"
        error_response(invoice.errors.full_messages.join(", "))
      end
    rescue StandardError => e
      log_error "Failed to create invoice: #{e.message}"
      log_error "Backtrace: #{e.backtrace.first(5).join('\n')}"
      error_response("Failed to create invoice: #{e.message}")
    end

    def send_reminder(invoice_id)
      invoice = @user.invoices.find_by(id: invoice_id)
      return error_response("Invoice not found") unless invoice
      return error_response("Can only send reminders for pending invoices") unless invoice.status == "pending"

      invoice.send_reminder

      success_response(
        { invoice_id: invoice.id },
        "Payment reminder sent to #{invoice.client_name}"
      )
    rescue StandardError => e
      log_error "Failed to send reminder: #{e.message}"
      error_response("Failed to send reminder: #{e.message}")
    end

    def mark_paid(invoice_id)
      invoice = @user.invoices.find_by(id: invoice_id)
      return error_response("Invoice not found") unless invoice

      invoice.mark_as_paid

      success_response(
        { invoice: format_for_response(invoice) },
        "Invoice marked as paid"
      )
    rescue StandardError => e
      log_error "Failed to mark invoice as paid: #{e.message}"
      error_response("Failed to mark invoice as paid: #{e.message}")
    end

    def fetch_invoices(filters = {})
      invoices = @user.invoices
      invoices = apply_filters(invoices, filters)
      invoices.order(created_at: :desc).limit(20)
    end

    def format_for_display(invoices)
      invoices.map { |invoice| format_for_response(invoice) }
    end

    private

    def build_invoice(invoice_data)
      log_info "Building invoice with: #{invoice_data.keys}"

      # Parse due date if it's a string, ensuring it's in the future
      due_date = if invoice_data["due_date"].present?
                   begin
                     parsed_date = Date.parse(invoice_data["due_date"].to_s)
                     # If the date is in the past, use 30 days from now instead
                     parsed_date < Date.current ? 30.days.from_now.to_date : parsed_date
                   rescue ArgumentError
                     30.days.from_now.to_date
                   end
                 else
                   30.days.from_now.to_date
                 end

      invoice_params = {
        client_name: invoice_data["client_name"],
        client_email: invoice_data["client_email"],
        amount: invoice_data["amount"].to_f,
        description: invoice_data["description"], # This should now work
        issue_date: Date.current,
        due_date: due_date,
        status: "draft",
        currency: @user.currency || "USD"
      }

      log_info "Invoice params: #{invoice_params}"
      log_info "Due date: #{due_date} (#{(due_date - Date.current).to_i} days from now)"
      @user.invoices.new(invoice_params)
    end


    def handle_stripe_integration(invoice, invoice_data)
      connect_account = @user.stripe_connect_account

      if connect_account&.can_accept_payments?
        create_stripe_invoice(invoice, invoice_data, connect_account)
      else
        log_info "No Stripe Connect or not ready for payments"
        success_response(
          { invoice: format_for_response(invoice) },
          "Invoice created successfully. Set up Stripe Connect to accept payments."
        )
      end
    end

    def create_stripe_invoice(invoice, invoice_data, connect_account)
      log_info "Creating Stripe invoice for invoice ID: #{invoice.id}"

      service = StripeConnectService.new(@user)
      stripe_result = service.create_invoice_with_fee({
                                                        amount: invoice.amount,
                                                        client_email: invoice.client_email,
                                                        client_name: invoice.client_name,
                                                        description: invoice.description,
                                                        currency: invoice.currency,
                                                        cashly_invoice_id: invoice.id,
                                                        days_until_due: (invoice.due_date - invoice.issue_date).to_i
                                                      })

      if stripe_result[:success]
        invoice.update!(
          stripe_invoice_id: stripe_result[:stripe_invoice].id,
          status: "pending"
        )

        # Use the StripeConnectService method to finalize and send
        send_result = service.finalize_and_send_invoice(invoice)

        if send_result[:success]
          success_response(
            {
              invoice: format_for_response(invoice),
              platform_fee: stripe_result[:platform_fee],
              stripe_invoice_url: send_result[:hosted_invoice_url]
            },
            "Invoice created and sent to #{invoice.client_name}! Platform fee: $#{stripe_result[:platform_fee]}"
          )
        else
          success_response(
            {
              invoice: format_for_response(invoice),
              platform_fee: stripe_result[:platform_fee]
            },
            "Invoice created but failed to send: #{send_result[:error]}"
          )
        end
      else
        log_error "Stripe invoice creation failed: #{stripe_result[:error]}"
        success_response(
          { invoice: format_for_response(invoice) },
          "Invoice created but Stripe integration failed: #{stripe_result[:error]}"
        )
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

    def format_for_response(invoice)
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
        stripe_invoice_id: invoice.stripe_invoice_id
      }
    end
  end
end
