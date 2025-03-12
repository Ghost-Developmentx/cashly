class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :accounts, dependent: :destroy
  has_many :transactions, through: :accounts
  has_many :invoices, dependent: :destroy
  has_many :budgets, dependent: :destroy
  has_many :plaid_tokens, dependent: :destroy

  # Validations
  validates :first_name, :last_name, :company_name, presence: true, if: :onboarding_completed?
  validates :phone_number, format: { with: /\A\+?\d+\z/, message: "only allows numbers and optionally a leading +" },
            allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Helper methods
  def full_name
    return email unless first_name.present? || last_name.present?
    [ first_name, last_name ].compact.join(" ")
  end

  def initials
    return email[0...2].upcase unless first_name.present? || last_name.present?
    [ first_name&.first, last_name&.first ].compact.join(" ").upcase
  end

  def needs_onboarding?
    !onboarding_completed?
  end

  # Profile competition percentage
  def profile_completion_percentage
    fields = [ :first_name, :last_name, :phone_number, :company_name,
               :business_type, :industry, :address_line1, :address_line2, :city, :state, :country ]

    completed = fields.count { |field| self.send(field).present? }
    (completed.to_f / fields.size * 100).round
  end

  def format_currency(amount)
    currency_symbol = case currency
    when "USD" then "$"
    when "EUR" then "€"
    when "GBP" then "£"
    when "JPY" then "¥"
    else "$"
    end

    "#{currency_symbol}#{amount}"
  end
end
