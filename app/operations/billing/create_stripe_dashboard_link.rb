module Billing
  class CreateStripeDashboardLink < BaseOperation
    attr_reader :user

    validates :user, presence: true

    def initialize(user:)
      @user = user
    end

    def execute
      connect_account = user.stripe_connect_account

      unless connect_account
        return failure("No Stripe Connect account found. Please set up Stripe Connect first.")
      end

      # Sync status first
      connect_account.sync_from_stripe!

      # Create dashboard link
      dashboard_url = create_dashboard_link(connect_account)

      if dashboard_url
        success(
          dashboard_url: dashboard_url,
          account_status: connect_account.status,
          can_accept_payments: connect_account.can_accept_payments?,
          message: build_status_message(connect_account)
        )
      else
        failure("Failed to create dashboard link")
      end
    rescue Stripe::StripeError => e
      failure("Stripe error: #{e.message}")
    end

    private

    def create_dashboard_link(connect_account)
      login_link = Stripe::Account.create_login_link(
        connect_account.stripe_account_id
      )
      login_link.url
    end

    def build_status_message(connect_account)
      case connect_account.status
      when "active"
        "✅ Your Stripe dashboard is ready! Your account is active and can accept payments."
      when "pending"
        "⚠️ Opening your Stripe dashboard. Please complete any remaining requirements to activate your account."
      when "rejected"
        "⚠️ Opening your Stripe dashboard. Please address the requirements to reactivate your account."
      else
        "Opening your Stripe dashboard..."
      end
    end
  end
end
