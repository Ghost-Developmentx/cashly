module Fin
  class InvoicesController < BaseController
    before_action :set_invoice, only: [:update, :send_reminder, :mark_paid]

    def index
      service = InvoiceService.new(current_user)
      invoices = service.list(filter_params)

      render_success(
        invoices: InvoiceFormatter.format_collection(invoices)
      )
    end

    def create
      service = InvoiceService.new(current_user)
      result = service.create(invoice_params)

      if result[:success]
        render_success(result)
      else
        render_error(result[:error])
      end
    end

    def send_invoice
      service = InvoiceService.new(current_user)
      result = service.send_invoice(params[:id])

      if result[:success]
        render_success(result)
      else
        render_error(result[:error])
      end
    end

    def update
      if @invoice.update(invoice_params)
        render_success(
          invoice: InvoiceFormatter.format(@invoice),
          message: "Invoice updated successfully"
        )
      else
        render_error(@invoice.errors.full_messages.join(", "))
      end
    end

    def send_reminder
      service = InvoiceService.new(current_user)
      result = service.send_reminder(params[:id])

      if result[:success]
        render_success(result)
      else
        render_error(result[:error])
      end
    end

    def mark_paid
      service = InvoiceService.new(current_user)
      result = service.mark_paid(params[:id])

      if result[:success]
        render_success(result)
      else
        render_error(result[:error])
      end
    end

    def sync
      service = InvoiceService.new(current_user)
      result = service.sync_from_stripe(params[:id])

      if result[:success]
        render_success(result)
      else
        render_error(result[:error])
      end
    end

    private

    def set_invoice
      @invoice = current_user.invoices.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render_error("Invoice not found", :not_found)
    end

    def invoice_params
      params.require(:invoice).permit(
        :client_name, :client_email, :client_address,
        :amount, :currency, :description, :notes,
        :issue_date, :due_date, :template
      )
    end

    def filter_params
      params.permit(:status, :client_name, :days, :limit)
    end
  end
end
