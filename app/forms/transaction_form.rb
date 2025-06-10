class TransactionForm
  include ActiveModel::Model

  attr_accessor :account_id, :account_name, :amount, :date,
                :description, :category_id, :category_name,
                :recurring, :notes

  validates :amount, presence: true, numericality: true
  validates :description, presence: true
  validates :date, presence: true
  validate :valid_date
  validate :account_present

  def initialize(attributes = {})
    super
    @date ||= Date.current
    @recurring ||= false
  end

  def to_transaction_attributes
    {
      amount: amount.to_f,
      description: description,
      date: parsed_date,
      recurring: recurring,
      notes: notes,
      category_id: category_id
    }.compact
  end

  def parsed_date
    case date
    when Date then date
    when String then Date.parse(date)
    when Time, DateTime then date.to_date
    else Date.current
    end
  rescue ArgumentError
    Date.current
  end

  private

  def valid_date
    parsed_date # This will trigger parsing
  rescue ArgumentError
    errors.add(:date, "is invalid")
  end

  def account_present
    unless account_id.present? || account_name.present?
      errors.add(:base, "Account must be specified")
    end
  end
end
