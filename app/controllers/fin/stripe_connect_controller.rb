module Fin
  class StripeConnectController < ApplicationController
    def status
      result = Billing::GetStripeConnectStatus.call(user: current_user)
      render_operation_result(result)
    end

    def setup
      result = Billing::SetupStripeConnect.call(
        user: current_user,
        params: setup_params
      )

      render_operation_result(result)
    end

    def create_onboarding_link
      # This is now handled by setup/restart operations
      render_error("Please use the setup endpoint", status: :bad_request)
    end

    def dashboard_link
      result = Billing::CreateStripeDashboardLink.call(user: current_user)
      render_operation_result(result)
    end

    def restart_setup
      result = Billing::RestartStripeSetup.call(user: current_user)
      render_operation_result(result)
    end

    def earnings
      result = Billing::GetStripeEarnings.call(
        user: current_user,
        period: params[:period] || "month"
      )

      render_operation_result(result)
    end

    def disconnect
      result = Billing::DisconnectStripeConnect.call(user: current_user)
      render_operation_result(result)
    end

    def onboarding_refresh
      # User refreshed during onboarding - create a new link
      service = StripeConnectService.new(current_user)
      onboarding_link = service.create_onboarding_link

      if onboarding_link
        redirect_to onboarding_link.url
      else
        # Redirect back to conversation with an error message
        redirect_to "#{frontend_url}/dashboard?stripe_error=onboarding_failed",
                    alert: "Unable to continue onboarding. Please try again."
      end
    end

    def onboarding_success
      connect_account = current_user.stripe_connect_account

      if connect_account
        # Sync the latest status from Stripe
        connect_account.sync_from_stripe!

        if connect_account.onboarding_complete?
          # Success - redirect back to conversation
          redirect_to "#{frontend_url}/dashboard?stripe_success=true",
                      notice: "Stripe Connect setup completed! You can now send invoices and accept payments."
        else
          # Still needs completion
          redirect_to "#{frontend_url}/dashboard?stripe_incomplete=true",
                      alert: "Onboarding needs to be completed. Please finish setting up your Stripe account."
        end
      else
        # Something went wrong
        redirect_to "#{frontend_url}/dashboard?stripe_error=setup_failed",
                    alert: "Something went wrong with your Stripe setup. Please try again."
      end
    end

    def webhook
      payload = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

      result = Billing::ProcessStripeWebhook.call(
        payload: payload,
        signature: sig_header
      )

      if result.success?
        render json: { received: true }
      else
        render json: { error: result.error }, status: :bad_request
      end
    end

    private

    def setup_params
      params.permit(:business_type, :country)
    end

    def frontend_url
      Rails.env.production? ? "https://app.cashly.com" : "http://localhost:4000"
    end
  end
end
