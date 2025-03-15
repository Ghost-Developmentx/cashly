# Clear existing ledger accounts
puts "Clearing existing ledger accounts..."
LedgerAccount.destroy_all

# Helper method to create accounts
def create_account(code, name, type, subtype = nil, parent = nil, description = nil, balance = nil)
  # Default balance based on account type if not specified
  default_balance = balance || case type
                               when 'asset', 'expense' then 'debit'
                               when 'liability', 'equity', 'revenue' then 'credit'
                               end

  display_order = case type
  when 'asset' then 1
  when 'liability' then 2
  when 'equity' then 3
  when 'revenue' then 4
  when 'expense' then 5
  end

  LedgerAccount.create!(
    code: code,
    name: name,
    account_type: type,
    account_subtype: subtype,
    parent_account: parent,
    description: description,
    default_balance: default_balance,
    display_order: display_order
  )
end

puts "Creating Chart of Accounts..."

# ASSETS (1000-1999)
assets = create_account('1000', 'Assets', 'asset', nil, nil, 'Resources owned by the business')

# Current Assets
current_assets = create_account('1100', 'Current Assets', 'asset', 'current_asset', assets, 'Assets expected to be converted to cash within one year')
create_account('1110', 'Cash and Cash Equivalents', 'asset', 'current_asset', current_assets)
create_account('1120', 'Accounts Receivable', 'asset', 'current_asset', current_assets, 'Amounts owed to the business by customers')
create_account('1130', 'Inventory', 'asset', 'current_asset', current_assets, 'Goods held for sale')
create_account('1140', 'Prepaid Expenses', 'asset', 'current_asset', current_assets, 'Expenses paid in advance')

# Fixed Assets
fixed_assets = create_account('1200', 'Fixed Assets', 'asset', 'fixed_asset', assets, 'Long-term tangible property')
create_account('1210', 'Land', 'asset', 'fixed_asset', fixed_assets)
create_account('1220', 'Buildings', 'asset', 'fixed_asset', fixed_assets)
create_account('1230', 'Equipment', 'asset', 'fixed_asset', fixed_assets)
create_account('1240', 'Vehicles', 'asset', 'fixed_asset', fixed_assets)
create_account('1250', 'Furniture and Fixtures', 'asset', 'fixed_asset', fixed_assets)

# Accumulated Depreciation (Contra Asset)
create_account('1300', 'Accumulated Depreciation', 'asset', 'contra_asset', assets, 'Accumulated depreciation of fixed assets', 'credit')

# Other Assets
other_assets = create_account('1400', 'Other Assets', 'asset', 'non_current_asset', assets)
create_account('1410', 'Intangible Assets', 'asset', 'non_current_asset', other_assets)

# LIABILITIES (2000-2999)
liabilities = create_account('2000', 'Liabilities', 'liability', nil, nil, 'Obligations owed by the business')

# Current Liabilities
current_liabilities = create_account('2100', 'Current Liabilities', 'liability', 'current_liability', liabilities, 'Obligations due within one year')
create_account('2110', 'Accounts Payable', 'liability', 'current_liability', current_liabilities, 'Amounts owed to suppliers')
create_account('2120', 'Accrued Expenses', 'liability', 'current_liability', current_liabilities, 'Expenses incurred but not yet paid')
create_account('2130', 'Taxes Payable', 'liability', 'current_liability', current_liabilities)
create_account('2140', 'Unearned Revenue', 'liability', 'current_liability', current_liabilities, 'Advance payments from customers')
create_account('2150', 'Short-term Loans', 'liability', 'current_liability', current_liabilities)

# Long-term Liabilities
long_term_liabilities = create_account('2200', 'Long-term Liabilities', 'liability', 'non_current_liability', liabilities, 'Obligations due beyond one year')
create_account('2210', 'Mortgages Payable', 'liability', 'non_current_liability', long_term_liabilities)
create_account('2220', 'Long-term Loans', 'liability', 'non_current_liability', long_term_liabilities)

# EQUITY (3000-3999)
equity = create_account('3000', 'Equity', 'equity', nil, nil, 'Owners\' interest in the business')
create_account('3100', 'Owner\'s Capital', 'equity', 'owner_equity', equity, 'Owner\'s investment in the business')
create_account('3200', 'Retained Earnings', 'equity', 'retained_earnings', equity, 'Accumulated profits reinvested in the business')
create_account('3300', 'Owner\'s Withdrawals', 'equity', 'owner_equity', equity, 'Owner\'s withdrawals from the business', 'debit')
create_account('3400', 'Current Year Earnings', 'equity', 'retained_earnings', equity)

# REVENUE (4000-4999)
revenue = create_account('4000', 'Revenue', 'revenue', nil, nil, 'Income from business activities')
create_account('4100', 'Sales Revenue', 'revenue', 'operating_revenue', revenue, 'Income from sales of goods or services')
create_account('4200', 'Service Revenue', 'revenue', 'operating_revenue', revenue, 'Income from services rendered')
create_account('4300', 'Interest Income', 'revenue', 'non_operating_revenue', revenue, 'Income from interest')
create_account('4400', 'Rental Income', 'revenue', 'non_operating_revenue', revenue, 'Income from property rentals')
create_account('4500', 'Other Income', 'revenue', 'non_operating_revenue', revenue, 'Miscellaneous income')

# EXPENSES (5000-5999)
expenses = create_account('5000', 'Expenses', 'expense', nil, nil, 'Costs incurred in business operations')

# Operating Expenses
operating_expenses = create_account('5100', 'Operating Expenses', 'expense', 'operating_expense', expenses)
create_account('5110', 'Salaries and Wages', 'expense', 'operating_expense', operating_expenses)
create_account('5120', 'Rent Expense', 'expense', 'operating_expense', operating_expenses)
create_account('5130', 'Utilities', 'expense', 'operating_expense', operating_expenses)
create_account('5140', 'Insurance', 'expense', 'operating_expense', operating_expenses)
create_account('5150', 'Office Supplies', 'expense', 'operating_expense', operating_expenses)
create_account('5160', 'Advertising and Marketing', 'expense', 'operating_expense', operating_expenses)
create_account('5170', 'Travel Expenses', 'expense', 'operating_expense', operating_expenses)
create_account('5180', 'Professional Fees', 'expense', 'operating_expense', operating_expenses)
create_account('5190', 'Repairs and Maintenance', 'expense', 'operating_expense', operating_expenses)

# Cost of Goods Sold
cogs = create_account('5200', 'Cost of Goods Sold', 'expense', 'operating_expense', expenses, 'Direct costs of producing goods sold')
create_account('5210', 'Purchases', 'expense', 'operating_expense', cogs)
create_account('5220', 'Freight', 'expense', 'operating_expense', cogs)
create_account('5230', 'Direct Labor', 'expense', 'operating_expense', cogs)

# Non-operating Expenses
non_operating_expenses = create_account('5300', 'Non-operating Expenses', 'expense', 'non_operating_expense', expenses)
create_account('5310', 'Interest Expense', 'expense', 'non_operating_expense', non_operating_expenses)
create_account('5320', 'Depreciation Expense', 'expense', 'non_operating_expense', non_operating_expenses)
create_account('5330', 'Tax Expense', 'expense', 'non_operating_expense', non_operating_expenses)

puts "Created #{LedgerAccount.count} ledger accounts."
