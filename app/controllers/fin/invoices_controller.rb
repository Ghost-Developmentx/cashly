module Fin
  class InvoicesController < BaseController
    def index
      result = Billing::ListInvoices.call(
        user: current_user,
        filters: filter_params
      )

      render_operation_result(result)
    end

    def create
      result = Billing::CreateInvoice.call(
        user: current_user,
        params: invoice_params
      )

      render_operation_result(result)
    end

    def send_invoice
      result = Billing::SendInvoice.call(
        user: current_user,
        invoice_id: params[:id]
      )

      render_operation_result(result)
    end

    def destroy
      result = Billing::DeleteInvoice.call(
        user: current_user,
        invoice_id: params[:id]
      )

      render_operation_result(result)
    end

    def show
      invoice = current_user.invoices.find(params[:id])
      render_success(
        invoice: Billing::InvoicePresenter.new(invoice).as_json
      )
    end

    def update
      invoice = current_user.invoices.find(params[:id])

      if invoice.update(invoice_params)
        render_success(
          invoice: Billing::InvoicePresenter.new(invoice).as_json,
          message: "Invoice updated successfully"
        )
      else
        render_error(invoice.errors.full_messages.join(", "))
      end
    end

    def send_reminder
      invoice = current_user.invoices.find(params[:id])

      if invoice.status == "pending"
        invoice.send_reminder
        render_success(message: "Payment reminder sent to #{invoice.client_name}")
      else
        render_error("Can only send reminders for pending invoices")
      end
    end

    def mark_paid
      invoice = current_user.invoices.find(params[:id])
      invoice.mark_as_paid

      render_success(
        invoice: Billing::InvoicePresenter.new(invoice).as_json,
        message: "Invoice marked as paid"
      )
    end

    def sync
      invoice = current_user.invoices.find(params[:id])

      # This will be refactored in a later step
      service = Fin::InvoiceService.new(current_user)
      result = service.sync_from_stripe(params[:id])

      render_operation_result(result)
    end

    private

    def invoice_params
      params.require(:invoice).permit(
        :client_name, :client_email, :client_address,
        :amount, :currency, :description, :notes,
        :issue_date, :due_date, :template, :days_until_due
      )
    end

    def filter_params
      params.permit(:status, :client_name, :days, :limit)
    end
  end
end
