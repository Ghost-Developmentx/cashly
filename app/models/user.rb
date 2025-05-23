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

  # Validations
  validates :first_name, :last_name, presence: true, if: :onboarding_completed?
  validates :phone_number, format: { with: /\A\+?\d+\z/, message: "only allows numbers and optionally a leading +" },
            allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  after_initialize :set_default_settings, if: :new_record?

  # Helper methods
  def full_name
    return email unless first_name.present? || last_name.present?
    [ first_name, last_name ].compact.join(" ")
  end

  def needs_onboarding?
    !onboarding_completed?
  end

  private
  def set_default_settings
    self.currency ||= "USD"
    self.timezone ||= "America/New_York"
    self.date_format ||= "MM/DD/YYYY"
    self.theme ||= "light"
    self.language ||= "en"
    self.notification_settings ||= {}
  end
end
