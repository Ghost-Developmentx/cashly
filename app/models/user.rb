class User < ApplicationRecord
  has_many :accounts, dependent: :destroy
  has_many :transactions, through: :accounts
  has_many :invoices, dependent: :destroy
  has_many :budgets, dependent: :destroy
  has_many :plaid_tokens, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_many :journal_entries, dependent: :destroy
  has_many :forecasts, dependent: :destroy
  has_many :fin_conversations, dependent: :destroy
  has_one :stripe_connect_account, dependent: :destroy

  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :clerk_id, presence: true, uniqueness: true

  after_initialize :set_default_settings, if: :new_record?

  # Helper methods
  def full_name
    return email unless first_name.present? || last_name.present?
    [ first_name, last_name ].compact.join(" ")
  end

  def display_name
    full_name.presence || email.split('@').first
  end

  def stripe_connect_enabled?
    stripe_connect_account&.can_accept_payments?
  end

  def stripe_connect_setup_complete?
    stripe_connect_account&.onboarding_complete?
  end

  def stripe_connect_status
    if stripe_connect_account
      {
        connected: true,
        status: stripe_connect_account.status,
        charges_enabled: stripe_connect_account.charges_enabled,
        payouts_enabled: stripe_connect_account.payouts_enabled,
        details_submitted: stripe_connect_account.details_submitted,
        onboarding_complete: stripe_connect_account.onboarding_complete?,
        can_accept_payments: stripe_connect_account.can_accept_payments?,
        platform_fee_percentage: stripe_connect_account.platform_fee_percentage,
        requirements: stripe_connect_account.requirements
      }
    else
      {
        connected: false,
        status: "not_connected",
        charges_enabled: false,
        payouts_enabled: false,
        details_submitted: false,
        onboarding_complete: false,
        can_accept_payments: false,
        platform_fee_percentage: 2.9
      }
    end
  end

  private
  def set_default_settings
    self.currency ||= "USD"
    self.timezone ||= "America/New_York"
    self.date_format ||= "MM/DD/YYYY"
    self.theme ||= "light"
    self.language ||= "en"
    self.notification_settings ||= {}
    self.onboarding_completed ||= false
  end
end
