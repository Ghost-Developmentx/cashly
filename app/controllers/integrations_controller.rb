# app/controllers/integrations_controller.rb
class IntegrationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_integration, only: [ :destroy ]

  def index
    @integrations = current_user.integrations.order(:provider)

    # Check which integrations are configured
    @available_integrations = {
      stripe: {
        name: "Stripe",
        description: "Send professional invoices and accept online payments",
        connected: current_user.integrations.active.by_provider("stripe").exists?,
        icon: "bi-credit-card"
      },
      plaid: {
        name: "Plaid",
        description: "Connect your bank accounts securely",
        connected: current_user.integrations.active.by_provider("plaid").exists?,
        icon: "bi-bank"
      },
      quickbooks: {
        name: "QuickBooks",
        description: "Sync with your QuickBooks accounting",
        connected: current_user.integrations.active.by_provider("quickbooks").exists?,
        icon: "bi-journal-check"
      },
      xero: {
        name: "Xero",
        description: "Connect with your Xero accounting software",
        connected: current_user.integrations.active.by_provider("xero").exists?,
        icon: "bi-calculator"
      }
    }
  end

  def new
    # Show connection form for a specific provider
    @provider = params[:provider]

    unless Integration::PROVIDERS.include?(@provider)
      redirect_to integrations_path, alert: "Invalid integration provider."
      return
    end

    # Check if already connected
    if current_user.integrations.active.by_provider(@provider).exists?
      redirect_to integrations_path, notice: "You are already connected to #{@provider.titleize}."
      return
    end

    # Render the appropriate form
    render "new_#{@provider}"
  end

  def create
    @provider = params[:provider]

    unless Integration::PROVIDERS.include?(@provider)
      redirect_to integrations_path, alert: "Invalid integration provider."
      return
    end

    # Handle based on provider
    case @provider
    when "stripe"
      handle_stripe_integration
    when "plaid"
      handle_plaid_integration
    when "quickbooks"
      handle_quickbooks_integration
    when "xero"
      handle_xero_integration
    else
      redirect_to integrations_path, alert: "Integration with #{@provider.titleize} is not yet supported."
    end
  end

  def destroy
    provider_name = @integration.provider.titleize

    if @integration.disconnect
      redirect_to integrations_path, notice: "Successfully disconnected from #{provider_name}."
    else
      redirect_to integrations_path, alert: "There was a problem disconnecting from #{provider_name}."
    end
  end

  # Provider-specific setup pages

  def stripe
    # Show Stripe setup page
    @connected = current_user.integrations.active.by_provider("stripe").exists?

    if @connected
      @integration = current_user.integrations.active.by_provider("stripe").first

      # Get some basic Stripe account info
      begin
        Stripe.api_key = @integration.credentials
        @account = Stripe::Account.retrieve
      rescue Stripe::StripeError => e
        @account = nil
        @error = e.message
      end
    end
  end

  def connect_stripe
    # Connect to Stripe with API key
    api_key = params[:api_key]

    if api_key.blank?
      redirect_to stripe_integrations_path, alert: "API key cannot be blank."
      return
    end

    integration = Integration.connect_stripe(current_user, api_key)

    if integration
      redirect_to stripe_integrations_path, notice: "Successfully connected to Stripe!"
    else
      redirect_to stripe_integrations_path, alert: "Could not connect to Stripe with the provided API key."
    end
  end

  private

  def set_integration
    @integration = current_user.integrations.find(params[:id])
  end

  def handle_stripe_integration
    # This is handled by connect_stripe
    redirect_to stripe_integrations_path
  end

  def handle_plaid_integration
    # Implement Plaid connection flow
    redirect_to integrations_path, notice: "Plaid integration coming soon."
  end

  def handle_quickbooks_integration
    # Implement QuickBooks connection flow
    redirect_to integrations_path, notice: "QuickBooks integration coming soon."
  end

  def handle_xero_integration
    # Implement Xero connection flow
    redirect_to integrations_path, notice: "Xero integration coming soon."
  end
end