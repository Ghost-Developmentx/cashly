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
      service = StripeConnectService.new(@user)
      service.create_dashboard_link
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
