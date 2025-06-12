module Billing
  class GetStripeConnectStatus < BaseOperation
    attr_reader :user

    validates :user, presence: true

    def initialize(user:)
      @user = user
    end

    def execute
      connect_account = user.stripe_connect_account

      if connect_account
        # Sync latest status from Stripe
        sync_account_status(connect_account)

        stripe_account = Billing::StripeAccount.new(connect_account)

        success(
          connected: true,
          status: connect_account.status,
          charges_enabled: connect_account.charges_enabled,
          payouts_enabled: connect_account.payouts_enabled,
          details_submitted: connect_account.details_submitted,
          onboarding_complete: stripe_account.onboarding_complete?,
          can_accept_payments: stripe_account.ready_for_payments?,
          platform_fee_percentage: connect_account.platform_fee_percentage,
          requirements: connect_account.requirements,
          status_message: stripe_account.status_message,
          requirements_message: stripe_account.requirements_message
        )
      else
        success(
          connected: false,
          status: "not_connected",
          charges_enabled: false,
          payouts_enabled: false,
          details_submitted: false,
          onboarding_complete: false,
          can_accept_payments: false,
          platform_fee_percentage: 2.9
        )
      end
    end

    private

    def sync_account_status(connect_account)
      connect_account.sync_from_stripe!
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to sync Stripe account: #{e.message}"
      # Continue with cached data if sync fails
    end
  end
end
