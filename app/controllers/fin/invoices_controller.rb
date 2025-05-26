module Fin
  class InvoicesController < ApplicationController
    before_action :set_invoice, only: [ :update, :send_reminder, :mark_paid ]

    def create
      invoice_data = invoice_params

      # Create an invoice through FinService or directly
      invoice = current_user.invoices.build(invoice_data)
      invoice.status = "draft"
      invoice.issue_date ||= Date.current
      invoice.due_date ||= 30.days.from_now

      if invoice.save
        render json: {
          success: true,
          invoice: format_invoice(invoice),
          message: "Invoice created successfully"
        }
      else
        render json: {
          success: false,
          error: invoice.errors.full_messages.join(", ")
        }, status: :unprocessable_entity
      end
    end

    def send_invoice
      invoice_id = params[:id]

      result = Fin::InvoiceManager.new(current_user).send(:send_invoice, invoice_id)

      if result[:success]
        render json: result
      else
        render json: result, status: :unprocessable_entity
      end
    end

    def update
      if @invoice.update(invoice_params)
        render json: {
          success: true,
          invoice: format_invoice(@invoice),
          message: "Invoice updated successfully"
        }
      else
        render json: {
          success: false,
          error: @invoice.errors.full_messages.join(", ")
        }, status: :unprocessable_entity
      end
    end

    def send_reminder
      if @invoice.status != "pending"
        render json: {
          success: false,
          error: "Can only send reminders for pending invoices"
        }, status: :unprocessable_entity
        return
      end

      # Send a reminder through the Invoice model method
      @invoice.send_reminder

      render json: {
        success: true,
        message: "Payment reminder sent to #{@invoice.client_name}"
      }
    end

    def mark_paid
      if @invoice.status == "paid"
        render json: {
          success: false,
          error: "Invoice is already marked as paid"
        }, status: :unprocessable_entity
        return
      end

      @invoice.mark_as_paid

      render json: {
        success: true,
        invoice: format_invoice(@invoice),
        message: "Invoice marked as paid"
      }
    end

    private

    def set_invoice
      @invoice = current_user.invoices.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        error: "Invoice not found"
      }, status: :not_found
    end

    def invoice_params
      params.require(:invoice).permit(
        :client_name, :client_email, :client_address,
        :amount, :currency, :description, :notes,
        :issue_date, :due_date, :template
      )
    end

    def format_invoice(invoice)
      {
        id: invoice.id,
        client_name: invoice.client_name,
        client_email: invoice.client_email,
        amount: invoice.amount.to_f,
        currency: invoice.currency,
        status: invoice.status,
        issue_date: invoice.issue_date.strftime("%Y-%m-%d"),
        due_date: invoice.due_date.strftime("%Y-%m-%d"),
        invoice_number: invoice.generate_invoice_number,
        description: invoice.description,
        stripe_invoice_id: invoice.stripe_invoice_id,
        created_at: invoice.created_at.iso8601
      }
    end
  end
end
