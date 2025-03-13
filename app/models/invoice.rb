class Invoice < ApplicationRecord
  belongs_to :user

  # Validations
  validates :client_name, :amount, :issue_date, :due_date, presence: true
  validates :client_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Callbacks
  after_save :sync_with_stripe, if: -> { saved_change_to_status? && status == "pending" }

  # Define possible statuses
  STATUSES = %w[draft pending paid cancelled overdue].freeze
  PAYMENT_STATUSES = %w[awaiting_payment processing paid failed].freeze
  RECURRING_INTERVALS = %w[weekly monthly quarterly yearly].freeze
  TEMPLATES = %w[default professional minimalist modern elegant].freeze

  # Scopes
  scope :drafts, -> { where(status: "draft") }
  scope :pending, -> { where(status: "pending") }
  scope :paid, -> { where(status: "paid") }
  scope :overdue, -> { where("status = 'pending' AND due_date < ?", Date.today) }
  scope :recurring, -> { where(recurring: true) }

  # Methods for invoice creation and management
  def generate_invoice_number
    "INV-#{id.to_s.rjust(5, '0')}"
  end

  def mark_as_sent
    update(status: "pending") if status == "draft"
  end

  def mark_as_paid
    update(status: "paid", payment_status: "paid")
  end

  def mark_as_overdue
    update(status: "overdue") if status == "pending" && due_date < Date.today
  end

  def days_until_due
    return 0 if due_date.nil?
    (due_date.to_date - Date.today).to_i
  end

  def overdue?
    status == "pending" && due_date < Date.today
  end

  # Stripe integration methods
  def sync_with_stripe
    return true if stripe_invoice_id.present?

    # Use the StripeService to create an invoice in Stripe
    stripe_service = StripeService.new(user)
    stripe_invoice = stripe_service.create_invoice(self)

    if stripe_invoice
      stripe_service.finalize_and_send_invoice(self)
    end
  end

  def check_payment_status
    return unless stripe_invoice_id.present?

    stripe_service = StripeService.new(user)
    stripe_service.check_payment_status(self)
  end

  def setup_recurring(interval, period)
    return false unless %w[weekly monthly quarterly yearly].include?(interval)

    stripe_service = StripeService.new(user)
    subscription = stripe_service.create_recurring_invoice(self, interval, period)

    subscription.present?
  end

  def cancel_recurring
    return false unless recurring? && stripe_subscription_id.present?

    stripe_service = StripeService.new(user)
    stripe_service.cancel_recurring_invoice(self)
  end

  def send_reminder
    # Logic to send a payment reminder email
    InvoiceMailer.payment_reminder(self).deliver_later if status == "pending"
  end

  # Helper methods for invoice customization
  def template_name
    TEMPLATES.include?(template) ? template : "default"
  end

  def template_path
    "invoices/templates/#{template_name}"
  end

  def formatted_currency
    Money.new(amount * 100, currency.upcase).format
  end

  # Methods for handling custom fields
  def set_custom_field(key, value)
    self.custom_fields = {} if custom_fields.nil?
    self.custom_fields[key] = value
    save
  end

  def get_custom_field(key)
    custom_fields&.dig(key)
  end
end
