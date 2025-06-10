class InvoiceForm
  include ActiveModel::Model

  attr_accessor :client_name, :client_email, :amount, :description,
                :due_date, :currency, :days_until_due

  validates :client_name, presence: true
  validates :client_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true

  def initialize(attributes = {})
    super
    @currency ||= "USD"
    @days_until_due ||= 30
  end

  def to_invoice_attributes
    {
      client_name: client_name,
      client_email: client_email,
      amount: amount.to_f,
      description: description,
      issue_date: Date.current,
      due_date: calculate_due_date,
      currency: currency,
      status: "draft"
    }
  end

  def to_stripe_attributes
    {
      client_name: client_name,
      client_email: client_email,
      amount: amount.to_f,
      description: description,
      days_until_due: days_until_due.to_i,
      currency: currency.downcase
    }
  end

  private

  def calculate_due_date
    if due_date.present?
      parsed = Date.parse(due_date.to_s) rescue nil
      parsed && parsed > Date.current ? parsed : 30.days.from_now.to_date
    else
      days_until_due.to_i.days.from_now.to_date
    end
  end
end
