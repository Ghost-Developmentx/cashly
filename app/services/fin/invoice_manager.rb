module Fin
  class InvoiceManager < BaseService
    def initialize(user)
      @user = user
    end

    def create(invoice_data)
      invoice = build_invoice(invoice_data)

      if invoice.save
        handle_stripe_integration(invoice, invoice_data)
      else
        error_response(invoice.errors.full_messages.join(", "))
      end
    rescue StandardError => e
      log_error "Failed to create invoice: #{e.message}"
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
      @user.invoices.new(
        client_name: invoice_data["client_name"],
        client_email: invoice_data["client_email"],
        amount: invoice_data["amount"],
        description: invoice_data["description"],
        issue_date: Date.current,
        due_date: invoice_data["due_date"] || 30.days.from_now,
        status: "draft",
        currency: @user.currency || "USD"
      )
    end

    def handle_stripe_integration(invoice, invoice_data)
      connect_account = @user.stripe_connect_account

      if connect_account&.can_accept_payments?
        create_stripe_invoice(invoice, invoice_data, connect_account)
      else
        success_response(
          { invoice: format_for_response(invoice) },
          "Invoice created successfully. Set up Stripe Connect to accept payments."
        )
      end
    end

    def create_stripe_invoice(invoice, invoice_data, connect_account)
      service = StripeConnectService.new(@user)
      stripe_result = service.create_invoice_with_fee({
                                                        amount: invoice.amount,
                                                        client_email: invoice.client_email,
                                                        client_name: invoice.client_name,
                                                        description: invoice.description,
                                                        currency: invoice.currency,
                                                        cashly_invoice_id: invoice.id
                                                      })

      if stripe_result[:success]
        invoice.update!(
          stripe_invoice_id: stripe_result[:stripe_invoice].id,
          status: "pending"
        )

        success_response(
          {
            invoice: format_for_response(invoice),
            platform_fee: stripe_result[:platform_fee]
          },
          "Invoice created with Stripe Connect! Platform fee: $#{stripe_result[:platform_fee]}"
        )
      else
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
