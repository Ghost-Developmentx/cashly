module Billing
  class RestartStripeSetup < BaseOperation
    attr_reader :user

    validates :user, presence: true

    def initialize(user:)
      @user = user
    end

    def execute
      existing_account = user.stripe_connect_account

      if existing_account && existing_account.status == "active"
        return failure("Cannot restart setup for an active account")
      end

      # Delete existing account if present
      if existing_account
        safely_remove_existing_account(existing_account)
      end

      # Create new account
      result = Billing::SetupStripeConnect.call(
        user: user,
        params: { business_type: "individual", country: "US" }
      )

      if result.success?
        success(
          account_id: result.data[:account_id],
          onboarding_url: result.data[:onboarding_url],
          message: "Stripe setup restarted. Please complete the onboarding process."
        )
      else
        failure(result.error)
      end
    end

    private

    def safely_remove_existing_account(account)
      # Don't actually delete from Stripe, just disconnect locally
      account.destroy
      Rails.logger.info "Disconnected Stripe account #{account.stripe_account_id} for user #{user.id}"
    rescue StandardError => e
      Rails.logger.error "Error removing Stripe account: #{e.message}"
      # Continue anyway
    end
  end
end
