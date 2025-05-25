module Fin
  class StripeConnectManager < BaseService
    def initialize(user)
      @user = user
    end

    def status
      connect_account = @user.stripe_connect_account

      if connect_account
        connect_account.sync_from_stripe!
        build_connected_status(connect_account)
      else
        build_disconnected_status
      end
    rescue StandardError => e
      log_error "Failed to get Stripe Connect status: #{e.message}"
      error_response("Failed to get Stripe Connect status: #{e.message}")
    end

    def create_account(account_params)
      return error_response("You already have a Stripe Connect account set up") if @user.stripe_connect_account.present?

      service = StripeConnectService.new(@user)
      result = service.create_express_account(
        country: account_params["country"] || "US",
        business_type: account_params["business_type"] || "individual"
      )

      if result[:success]
        success_response(
          {
            onboarding_url: result[:onboarding_url],
            account_id: result[:account].stripe_account_id
          },
          "Stripe Connect account created! Complete your onboarding to start accepting payments."
        )
      else
        error_response(result[:error])
      end
    rescue StandardError => e
      log_error "Failed to create Stripe Connect account: #{e.message}"
      error_response("Failed to create Stripe Connect account: #{e.message}")
    end

    def create_dashboard_link
      connect_account = @user.stripe_connect_account

      unless connect_account
        return {
          success: false,
          error: "No Stripe Connect account found",
          action_needed: "restart_setup",
          restart_message: "You need to set up Stripe Connect first.",
          can_restart: true
        }
      end

      # Sync the latest status from Stripe
      connect_account.sync_from_stripe!

      # Always try to create a dashboard link-users need access to complete requirements
      service = StripeConnectService.new(@user)
      dashboard_result = service.create_dashboard_link

      if dashboard_result && dashboard_result[:success]
        # Add helpful context based on account status
        enhanced_message = case connect_account.status
                           when "active"
                             "✅ Your Stripe dashboard is ready! Your account is active and can accept payments."
                           when "pending"
                             "⚠️ Opening your Stripe dashboard. Please complete any remaining requirements to activate your account."
                           when "rejected"
                             "⚠️ Opening your Stripe dashboard. Please address the requirements (like uploading ID) to reactivate your account."
                           else
                             dashboard_result[:message] || "Opening your Stripe dashboard..."
                           end

        success_response(
          {
            dashboard_url: dashboard_result[:dashboard_url],
            account_status: connect_account.status,
            can_accept_payments: connect_account.can_accept_payments?
          },
          enhanced_message
        )
      else
        error_response(
          dashboard_result&.dig(:error) || "Failed to create dashboard link"
        )
      end
    rescue StandardError => e
      log_error "Failed to create dashboard link: #{e.message}"
      error_response("Failed to create dashboard link: #{e.message}")
    end

    private

    def build_connected_status(connect_account)
      {
        connected: true,
        status: connect_account.status,
        charges_enabled: connect_account.charges_enabled,
        payouts_enabled: connect_account.payouts_enabled,
        details_submitted: connect_account.details_submitted,
        onboarding_complete: connect_account.onboarding_complete?,
        platform_fee_percentage: connect_account.platform_fee_percentage,
        can_accept_payments: connect_account.can_accept_payments?,
        requirements: connect_account.requirements
      }
    end

    def build_disconnected_status
      {
        connected: false,
        status: "not_connected",
        charges_enabled: false,
        payouts_enabled: false,
        details_submitted: false,
        onboarding_complete: false,
        can_accept_payments: false
      }
    end
  end
end
