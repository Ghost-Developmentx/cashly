class InvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invoice, only: [ :show, :edit, :update, :destroy ]

  def index
    @invoices = current_user.invoices.order(due_date: :desc)

    # Calculate totals
    @total_invoiced = @invoices.sum(:amount)
    @pending_amount = @invoices.where(status: "pending").sum(:amount)
    @overdue_amount = @invoices.where(status: "pending").where("due_date < ?", Date.today).sum(:amount)

    # Group by status for summary
    @status_summary = current_user.invoices.group("status").count
  end

  def show
  end

  def new
    @invoice = Invoice.new
    @invoice.issue_date = Date.today
    @invoice.due_date = Date.today + 30.days
  end

  def edit
  end

  def create
    @invoice = current_user.invoices.build(invoice_params)

    respond_to do |format|
      if @invoice.save
        format.html { redirect_to @invoice, notice: "Invoice was successfully created." }
        format.json { render :show, status: :created, location: @invoice }
      else
        format.html { render :new }
        format.json { render json: @invoice.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if @invoice.update(invoice_params)
        format.html { redirect_to @invoice, notice: "Invoice was successfully updated." }
        format.json { render :show, status: :ok, location: @invoice }
      else
        format.html { render :edit }
        format.json { render json: @invoice.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    @invoice.destroy
    respond_to do |format|
      format.html { redirect_to invoices_url, notice: "Invoice was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private

  def set_invoice
    @invoice = current_user.invoices.find(params[:id])
  end

  def invoice_params
    params.expect(invoice: [ :client_name, :amount, :issue_date, :due_date, :status ])
  end
end
