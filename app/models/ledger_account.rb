class LedgerAccount < ApplicationRecord
  # Relationships
  belongs_to :parent_account, class_name: "LedgerAccount", optional: true
  has_many :child_accounts, class_name: "LedgerAccount", foreign_key: "parent_account_id", dependent: :restrict_with_error

  # Validations
  validates :name, presence: true
  validates :code, presence: true, uniqueness: true, format: { with: /\A\d+\z/, message: "must only contain numbers" }
  validates :account_type, presence: true, inclusion: { in: %w[asset liability equity revenue expense] }
  validates :default_balance, presence: true, inclusion: { in: %w[debit credit] }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :root_accounts, -> { where(parent_account_id: nil) }

  # Account type scopes
  scope :assets, -> { where(account_type: "asset") }
  scope :liabilities, -> { where(account_type: "liability") }
  scope :equity, -> { where(account_type: "equity") }
  scope :revenue, -> { where(account_type: "revenue") }
  scope :expenses, -> { where(account_type: "expense") }

  # Order by display_order and code
  default_scope { order(:display_order, :code) }

  # Instance methods
  def full_name
    "#{code} - #{name}"
  end

  def path
    if parent_account
      "#{parent_account.path} > #{name}"
    else
      name
    end
  end

  def root?
    parent_account.nil?
  end

  def leaf?
    child_accounts.empty?
  end

  def self_and_descendants
    [ self ] + descendants
  end

  def descendants
    child_accounts.flat_map(&:self_and_descendants)
  end

  # Class methods
  def self.account_types
    %w[asset liability equity revenue expense]
  end

  def self.default_account_subtypes
    {
      "asset" => %w[current_asset fixed_asset non_current_asset contra_asset],
      "liability" => %w[current_liability non_current_liability],
      "equity" => %w[owner_equity retained_earnings],
      "revenue" => %w[operating_revenue non_operating_revenue],
      "expense" => %w[operating_expense non_operating_expense]
    }
  end

  # Method to determine normal balance (debit/credit)
  def normal_balance
    default_balance
  end

  # Method to determine if account normally increases with debits
  def increases_with_debit?
    default_balance == "debit"
  end

  # Method to determine if account normally increases with credits
  def increases_with_credit?
    default_balance == "credit"
  end
end
