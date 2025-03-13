# app/controllers/invoices_controller.rb
class InvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invoice, only: [ :show, :edit, :update, :destroy, :send_invoice,
                                     :mark_as_paid, :set_recurring, :cancel_recurring,
                                     :preview, :send_reminder, :payment_status ]

  def index
    # Get all invoices
    base_query = current_user.invoices

    # Filter by status if provided
    if params[:status].present? && Invoice::STATUSES.include?(params[:status])
      base_query = base_query.where(status: params[:status])
    end

    # Order and paginate
    @invoices = base_query.order(issue_date: :desc).page(params[:page]).per(10)

    # Calculate totals
    @total_invoiced = current_user.invoices.sum(:amount)
    @pending_amount = current_user.invoices.where(status: "pending").sum(:amount)
    @overdue_amount = current_user.invoices.where(status: "pending")
                                  .where("due_date < ?", Date.today).sum(:amount)

    # Group by status for summary - FIXED: Using a raw SQL approach
    @status_summary = current_user.invoices.group("status").count
  end

  def recurring
    @invoices = current_user.invoices.where(recurring: true).order(next_payment_date: :asc)

    # Paginate
    @invoices = @invoices.page(params[:page]).per(10)
  end

  def show
    # Check if we need to refresh the payment status
    if @invoice.status == "pending" && @invoice.stripe_invoice_id.present?
      @invoice.check_payment_status
    end

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "invoice_#{@invoice.id}",
               template: @invoice.template_path,
               layout: "pdf"
      end
    end
  end

  def new
    @invoice = current_user.invoices.new
    @invoice.issue_date = Date.today
    @invoice.due_date = Date.today + 30.days
    @invoice.status = "draft"
    @invoice.currency = current_user.currency || "USD"

    # Set default template
    @invoice.template = "default"
  end

  def edit
    # Only allow editing if draft, or we're just updating templates
    unless @invoice.status == "draft" || params[:template_only]
      redirect_to @invoice, alert: "Cannot edit invoices that have been sent or paid."
      nil
    end
  end

  def create
    @invoice = current_user.invoices.build(invoice_params)
    @invoice.status = "draft" # Always start as draft

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
    # Only allow updates if draft or template only
    unless @invoice.status == "draft" || params[:invoice][:template]
      redirect_to @invoice, alert: "Cannot edit invoices that have been sent or paid."
      return
    end

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
    # Only allow deletion of draft invoices
    unless @invoice.status == "draft"
      redirect_to invoices_url, alert: "Cannot delete invoices that have been sent or paid."
      return
    end

    @invoice.destroy
    respond_to do |format|
      format.html { redirect_to invoices_url, notice: "Invoice was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # Custom actions for Stripe integration

  def send_invoice
    # Check if Stripe is configured
    unless current_user.integrations.active.by_provider("stripe").exists?
      redirect_to @invoice, alert: "Please connect your Stripe account before sending invoices."
      return
    end

    # Only send draft invoices
    unless @invoice.status == "draft"
      redirect_to @invoice, alert: "This invoice has already been sent."
      return
    end

    # Send invoice through Stripe
    if @invoice.sync_with_stripe
      redirect_to @invoice, notice: "Invoice has been sent to #{@invoice.client_name}."
    else
      redirect_to @invoice, alert: "There was a problem sending the invoice. Please try again."
    end
  end

  def mark_as_paid
    # Only mark pending invoices as paid
    unless @invoice.status == "pending"
      redirect_to @invoice, alert: "Only pending invoices can be marked as paid."
      return
    end

    @invoice.mark_as_paid
    redirect_to @invoice, notice: "Invoice has been marked as paid."
  end

  def set_recurring
    # Validate parameters
    unless %w[weekly monthly quarterly yearly].include?(params[:interval]) &&
      params[:period].to_i.between?(1, 12)
      redirect_to @invoice, alert: "Invalid recurring parameters."
      return
    end

    # Setup recurring payments
    if @invoice.setup_recurring(params[:interval], params[:period].to_i)
      redirect_to @invoice, notice: "Recurring payments have been set up."
    else
      redirect_to @invoice, alert: "There was a problem setting up recurring payments."
    end
  end

  def cancel_recurring
    # Cancel recurring payments
    if @invoice.cancel_recurring
      redirect_to @invoice, notice: "Recurring payments have been cancelled."
    else
      redirect_to @invoice, alert: "There was a problem cancelling recurring payments."
    end
  end

  def preview
    # Return the invoice template as HTML
    render "invoices/templates/#{@invoice.template_name}", layout: "invoice_preview"
  end

  def send_reminder
    # Only send reminders for pending invoices
    unless @invoice.status == "pending"
      redirect_to @invoice, alert: "Reminders can only be sent for pending invoices."
      return
    end

    @invoice.send_reminder
    redirect_to @invoice, notice: "Payment reminder has been sent to #{@invoice.client_name}."
  end

  def payment_status
    # Check payment status via Stripe
    status = @invoice.check_payment_status

    respond_to do |format|
      format.html { redirect_to @invoice }
      format.json { render json: { status: status } }
    end
  end

  def templates
    # Return a list of available templates
    @templates = Invoice::TEMPLATES

    respond_to do |format|
      format.html
      format.json { render json: @templates }
    end
  end

  def preview_template
    # Create a temporary invoice object for the preview
    @temp_invoice = Invoice.new

    # Fill in the invoice details from params
    @temp_invoice.client_name = params[:client_name].presence || "Client Name"
    @temp_invoice.client_email = params[:client_email].presence || "client@example.com"
    @temp_invoice.client_address = params[:client_address].presence
    @temp_invoice.amount = params[:amount].presence || 0.0
    @temp_invoice.currency = params[:currency].presence || "usd"
    @temp_invoice.issue_date = params[:issue_date].presence ? Date.parse(params[:issue_date]) : Date.today
    @temp_invoice.due_date = params[:due_date].presence ? Date.parse(params[:due_date]) : Date.today + 30.days
    @temp_invoice.notes = params[:notes].presence
    @temp_invoice.terms = params[:terms].presence
    @temp_invoice.template = params[:template].presence || "default"
    @temp_invoice.status = "draft"

    # Attach the current user to the invoice for the preview
    @temp_invoice.instance_variable_set(:@user, current_user)
    def @temp_invoice.user
      @user
    end

    # Allow overriding company name for preview
    @company_name_override = params[:company_name].presence

    # Handle logo upload if present
    @logo_data = nil
    if params[:logo].present? && params[:logo].respond_to?(:read)
      @logo_data = params[:logo].read
    end

    # Use the temporary invoice for the view
    @invoice = @temp_invoice

    render "invoices/templates/#{@temp_invoice.template_name}", layout: "invoice_preview"
  end

  private

  def set_invoice
    @invoice = current_user.invoices.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(
      :client_name, :client_email, :client_address,
      :amount, :currency, :issue_date, :due_date,
      :status, :description, :notes, :terms, :template,
      custom_fields: {}
    )
  end
end
