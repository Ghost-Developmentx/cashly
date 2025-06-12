module Billing
  class DisconnectStripeConnect < BaseOperation
    attr_reader :user

    validates :user, presence: true

    def initialize(user:)
      @user = user
    end

    def execute
      connect_account = user.stripe_connect_account

      unless connect_account
        return failure("No Stripe Connect account to disconnect")
      end

      # Check for active invoices
      if user.invoices.pending.exists?
        return failure("Cannot disconnect while you have pending invoices")
      end

      # Disconnect the account
      connect_account.destroy

      success(
        message: "Stripe Connect account disconnected successfully"
      )
    rescue StandardError => e
      failure("Failed to disconnect: #{e.message}")
    end
  end
end
