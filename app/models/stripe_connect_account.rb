class StripeConnectAccount < ApplicationRecord
  belongs_to :user
  has_many :invoices, foreign_key: :stripe_connect_account_id

  validates :stripe_account_id, presence: true, uniqueness: true
  validates :platform_fee_percentage, presence: true,
            numericality: { greater_than: 0, less_than: 100 }

  BUSINESS_TYPES = %w[individual company non_profit government_entity].freeze
  STATUSES = %w[pending active inactive rejected].freeze

  validates :business_type, inclusion: { in: BUSINESS_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }
  scope :charges_enabled, -> { where(charges_enabled: true) }
  scope :payouts_enabled, -> { where(payouts_enabled: true) }

  def can_accept_payments?
    charges_enabled && status == "active"
  end

  def can_receive_payouts?
    payouts_enabled && status == "active"
  end

  def onboarding_complete?
    details_submitted && charges_enabled
  end

  def sync_from_stripe!
    return unless stripe_account_id.present?

    begin
      account = Stripe::Account.retrieve(stripe_account_id)

      update!(
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled,
        details_submitted: account.details_submitted,
        email: account.email,
        business_type: account.business_type,
        capabilities: account.capabilities&.to_h || {},
        requirements: account.requirements&.to_h || {},
        settings: account.settings&.to_h || {},
        created_at_stripe: Time.at(account.created),
        last_synced_at: Time.current
      )

      # Update status based on account state
      new_status = determine_status_from_stripe(account)
      update!(status: new_status) if new_status != status

      true
    rescue Stripe::StripeError => e
      Rails.logger.error "Failed to sync Stripe Connect account #{stripe_account_id}: #{e.message}"
      false
    end
  end

  private

  def determine_status_from_stripe(account)
    if account.charges_enabled && account.details_submitted
      "active"
    elsif account.requirements&.disabled_reason.present?
      "rejected"
    else
      "pending"
    end
  end
end
