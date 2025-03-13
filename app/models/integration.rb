class Integration < ApplicationRecord
  belongs_to :user

  # Encrypt sensitive data
  attr_encrypted :credentials, key: ENV["ENCRYPTION_KEY"]

  # Validations
  validates :provider, presence: true
  validates :provider, uniqueness: { scope: :user_id }

  # Providers
  PROVIDERS = %w[stripe plaid quickbooks xero].freeze

  # Statuses
  STATUSES = %w[active inactive error expired].freeze

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :by_provider, ->(provider) { where(provider: provider) }

  # Methods
  def active?
    status == "active" && (expires_at.nil? || expires_at > Time.current)
  end

  def update_last_used
    update(last_used_at: Time.current)
  end

  def refresh_token
    case provider
    when "stripe"
      # Stripe API keys don't expire
      true
    when "plaid"
      # Implement Plaid token refresh logic
    when "quickbooks"
      # Implement QuickBooks token refresh logic
    when "xero"
      # Implement Xero token refresh logic
    else
      # type code here
    end
  end

  def disconnect
    update(status: "inactive")

    # Perform provider-specific cleanup
    case provider
    when "stripe"
      # No specific cleanup needed
    when "plaid"
      # Implement Plaid disconnect logic
    when "quickbooks"
      # Implement QuickBooks disconnect logic
    when "xero"
      # Implement Xero disconnect logic
    else
      # type code here
    end
  end

  def self.connect_stripe(user, api_key)
    # First, verify the API key is valid
    begin
      Stripe.api_key = api_key
      Stripe::Account.retrieve

      # Create or update integration
      integration = user.integrations.find_or_initialize_by(provider: "stripe")
      integration.update(
        credentials: api_key,
        status: "active",
        connected_at: Time.current,
        last_used_at: Time.current
      )

      integration
    rescue Stripe::StripeError => e
      Rails.logger.error "Stripe connection error: #{e.message}"
      nil
    end
  end
end
