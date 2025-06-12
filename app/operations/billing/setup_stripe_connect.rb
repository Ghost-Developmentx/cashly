module Billing
  class SetupStripeConnect < BaseOperation
    attr_reader :user, :form

    validates :user, presence: true

    def initialize(user:, params: {})
      @user = user
      @form = StripeConnectSetupForm.new(params)
    end

    def execute
      validate_not_already_connected!
      validate_form!

      # Create Stripe Connect account
      stripe_account = create_stripe_account

      # Save to database
      connect_account = save_connect_account(stripe_account)

      # Create onboarding link
      onboarding_url = create_onboarding_link(connect_account)

      success(
        account_id: connect_account.stripe_account_id,
        onboarding_url: onboarding_url,
        message: "Stripe Connect account created! Complete your onboarding to start accepting payments."
      )
    rescue Stripe::StripeError => e
      failure("Failed to create Stripe Connect account: #{e.message}")
    end

    private

    def validate_not_already_connected!
      if user.stripe_connect_account.present?
        raise StandardError, "You already have a Stripe Connect account set up"
      end
    end

    def validate_form!
      unless form.valid?
        raise ActiveRecord::RecordInvalid.new(form)
      end
    end

    def create_stripe_account
      account_params = form.to_stripe_params.merge(
        email: user.email,
        metadata: {
          user_id: user.id,
          platform: "cashly"
        }
      )

      Stripe::Account.create(account_params)
    end

    def save_connect_account(stripe_account)
      user.create_stripe_connect_account!(
        stripe_account_id: stripe_account.id,
        account_type: "express",
        country: form.country,
        email: user.email,
        business_type: form.business_type,
        status: "pending",
        platform_fee_percentage: 2.9,
        charges_enabled: stripe_account.charges_enabled,
        payouts_enabled: stripe_account.payouts_enabled,
        details_submitted: stripe_account.details_submitted,
        capabilities: stripe_account.capabilities&.to_h || {},
        requirements: stripe_account.requirements&.to_h || {}
      )
    end

    def create_onboarding_link(connect_account)
      service = StripeConnectService.new(user)
      link = service.create_onboarding_link(connect_account.stripe_account_id)
      link.url
    end
  end
end
