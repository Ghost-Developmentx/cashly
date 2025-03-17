# Find the test user
user = User.find_by(email: "ghostdevelopmentx@protonmail.com")

if user.nil?
  puts "User with email ghostdevelopmentx@protonmail.com not found."
  exit
end

puts "Starting data seeding for user #{user.email}..."

# Create categories
puts "Creating categories..."
categories = [
  { name: "Housing", description: "Rent, mortgage, repairs, property taxes" },
  { name: "Transportation", description: "Gas, car payments, public transit, car insurance" },
  { name: "Food", description: "Groceries, restaurants, takeout" },
  { name: "Utilities", description: "Electricity, water, gas, internet, phone" },
  { name: "Insurance", description: "Health, life, home insurance (excluding car insurance)" },
  { name: "Healthcare", description: "Doctor visits, medications, medical procedures" },
  { name: "Debt Payments", description: "Credit card, student loans, personal loans" },
  { name: "Entertainment", description: "Movies, games, concerts, subscriptions" },
  { name: "Shopping", description: "Clothing, electronics, household items" },
  { name: "Personal Care", description: "Haircuts, gym, beauty products" },
  { name: "Education", description: "Tuition, books, courses" },
  { name: "Gifts & Donations", description: "Presents, charitable giving" },
  { name: "Travel", description: "Flights, hotels, vacation expenses" },
  { name: "Business", description: "Business expenses, office supplies" },
  { name: "Income", description: "Salary, freelance income, investments" },
  { name: "Investments", description: "Stock purchases, retirement contributions" },
  { name: "Taxes", description: "Income tax, property tax payments" },
  { name: "Miscellaneous", description: "Other expenses" }
]

category_objects = {}
categories.each do |category_attrs|
  category = Category.find_or_create_by(name: category_attrs[:name]) do |c|
    c.description = category_attrs[:description]
  end
  category_objects[category.name] = category
  puts "  Created category: #{category.name}"
end

# Create accounts
puts "Creating accounts..."
accounts = [
  { name: "Primary Checking", account_type: "checking", institution: "Bank of America", balance: 5421.63 },
  { name: "Savings", account_type: "savings", institution: "Bank of America", balance: 15780.28 },
  { name: "Credit Card", account_type: "credit_card", institution: "Chase", balance: -1240.87 },
  { name: "Investment", account_type: "investment", institution: "Vanguard", balance: 45670.91 },
  { name: "Business Checking", account_type: "checking", institution: "Wells Fargo", balance: 8743.22 }
]

account_objects = {}
accounts.each do |account_attrs|
  account = user.accounts.find_or_create_by(name: account_attrs[:name]) do |a|
    a.account_type = account_attrs[:account_type]
    a.institution = account_attrs[:institution]
    a.balance = account_attrs[:account_type] == "credit_card" ? -account_attrs[:balance].abs : account_attrs[:balance]
    a.last_synced = Time.current
  end
  account_objects[account.name] = account
  puts "  Created account: #{account.name} with balance #{account.balance}"
end

# Create recurring transaction templates
puts "Creating recurring transaction templates..."
recurring_transactions = [
  { account: "Primary Checking", category: "Income", description: "Salary Deposit", amount: 5500, day_of_month: 15, probability: 1.0 },
  { account: "Primary Checking", category: "Housing", description: "Rent Payment", amount: -2100, day_of_month: 1, probability: 1.0 },
  { account: "Primary Checking", category: "Utilities", description: "Electric Bill", amount: -120, day_of_month: 5, variance: 40, probability: 1.0 },
  { account: "Primary Checking", category: "Utilities", description: "Internet Bill", amount: -80, day_of_month: 7, probability: 1.0 },
  { account: "Primary Checking", category: "Utilities", description: "Water Bill", amount: -60, day_of_month: 10, variance: 20, probability: 1.0 },
  { account: "Primary Checking", category: "Utilities", description: "Phone Bill", amount: -95, day_of_month: 12, probability: 1.0 },
  { account: "Primary Checking", category: "Food", description: "Grocery Shopping", amount: -150, weekly: true, variance: 50, probability: 0.9 },
  { account: "Credit Card", category: "Food", description: "Restaurant Dinner", amount: -85, weekly: true, variance: 30, probability: 0.7 },
  { account: "Credit Card", category: "Entertainment", description: "Netflix Subscription", amount: -15.99, day_of_month: 3, probability: 1.0 },
  { account: "Credit Card", category: "Entertainment", description: "Spotify Subscription", amount: -9.99, day_of_month: 8, probability: 1.0 },
  { account: "Credit Card", category: "Personal Care", description: "Gym Membership", amount: -49.99, day_of_month: 2, probability: 1.0 },
  { account: "Primary Checking", category: "Transportation", description: "Gas Station", amount: -55, weekly: true, variance: 15, probability: 0.8 },
  { account: "Primary Checking", category: "Insurance", description: "Car Insurance", amount: -120, day_of_month: 20, frequency_months: 6, probability: 1.0 },
  { account: "Primary Checking", category: "Housing", description: "Home Insurance", amount: -150, day_of_month: 15, frequency_months: 12, probability: 1.0 },
  { account: "Primary Checking", category: "Transportation", description: "Car Payment", amount: -350, day_of_month: 10, probability: 1.0 },
  { account: "Savings", category: "Income", description: "Interest", amount: 12.50, day_of_month: 28, probability: 1.0 },
  { account: "Investment", category: "Income", description: "Dividend Payment", amount: 180, day_of_month: 16, frequency_months: 3, probability: 1.0 },
  { account: "Investment", category: "Investments", description: "401k Contribution", amount: 500, day_of_month: 15, probability: 1.0 },
  { account: "Business Checking", category: "Income", description: "Client Payment", amount: 2500, day_of_month: 23, variance: 1500, probability: 0.7 },
  { account: "Business Checking", category: "Business", description: "Office Supplies", amount: -120, monthly: true, variance: 80, probability: 0.6 },
  { account: "Business Checking", category: "Business", description: "Software Subscription", amount: -49.99, day_of_month: 5, probability: 1.0 },
  { account: "Credit Card", category: "Shopping", description: "Amazon Purchase", amount: -65, weekly: true, variance: 45, probability: 0.65 },
  { account: "Credit Card", category: "Shopping", description: "Clothing Purchase", amount: -120, monthly: true, variance: 80, probability: 0.5 },
  { account: "Primary Checking", category: "Debt Payments", description: "Credit Card Payment", amount: -1000, day_of_month: 25, probability: 1.0 }
]

# Create occasional transaction templates
occasional_transactions = [
  { account: "Credit Card", category: "Travel", description: "Flight Tickets", amount: -450, variance: 200, months_probability: { 3 => 0.3, 6 => 0.4, 11 => 0.5 } },
  { account: "Credit Card", category: "Travel", description: "Hotel Stay", amount: -350, variance: 150, months_probability: { 3 => 0.3, 6 => 0.4, 11 => 0.5 } },
  { account: "Credit Card", category: "Healthcare", description: "Doctor Visit", amount: -120, variance: 50, annual_probability: 0.7 },
  { account: "Credit Card", category: "Healthcare", description: "Pharmacy", amount: -45, variance: 25, annual_probability: 0.8 },
  { account: "Credit Card", category: "Gifts & Donations", description: "Birthday Gift", amount: -75, variance: 35, annual_probability: 0.95 },
  { account: "Primary Checking", category: "Gifts & Donations", description: "Charity Donation", amount: -100, variance: 50, months_probability: { 11 => 0.8, 12 => 0.9 } },
  { account: "Credit Card", category: "Shopping", description: "Electronics Purchase", amount: -300, variance: 200, annual_probability: 0.7 },
  { account: "Credit Card", category: "Entertainment", description: "Concert Tickets", amount: -120, variance: 40, annual_probability: 0.6 },
  { account: "Primary Checking", category: "Taxes", description: "Tax Payment", amount: -2500, months_probability: { 4 => 0.9 } },
  { account: "Credit Card", category: "Personal Care", description: "Haircut", amount: -45, variance: 15, frequency_months: 2, annual_probability: 0.9 },
  { account: "Credit Card", category: "Shopping", description: "Home Improvement", amount: -250, variance: 150, annual_probability: 0.65 },
  { account: "Credit Card", category: "Food", description: "Special Dinner", amount: -150, variance: 50, months_probability: { 2 => 0.4, 12 => 0.8 } },
  { account: "Primary Checking", category: "Miscellaneous", description: "Unexpected Expense", amount: -200, variance: 150, annual_probability: 0.7 },
  { account: "Business Checking", category: "Business", description: "Business Travel", amount: -750, variance: 250, annual_probability: 0.6 },
  { account: "Primary Checking", category: "Income", description: "Tax Refund", amount: 1200, variance: 500, months_probability: { 3 => 0.7, 4 => 0.8 } },
  { account: "Primary Checking", category: "Income", description: "Bonus", amount: 2000, variance: 1000, months_probability: { 12 => 0.8 } }
]

# Create transactions for the past year
puts "Creating a year of transactions..."
end_date = Date.today
start_date = end_date - 365.days
current_date = start_date

# Since batch insert doesn't trigger callbacks, we'll create transactions individually
transactions_count = 0

while current_date <= end_date
  daily_transactions = []

  # Process recurring transactions for this day
  recurring_transactions.each do |tx|
    # Check if this transaction should occur today
    should_add = false

    # Monthly transactions on specific day
    if tx[:day_of_month] && current_date.day == tx[:day_of_month]
      # Check if it has a frequency (e.g., every 3 months)
      if tx[:frequency_months]
        month_diff = (current_date.year * 12 + current_date.month) - (start_date.year * 12 + start_date.month)
        should_add = month_diff % tx[:frequency_months] == 0
      else
        should_add = true
      end
    end

    # Weekly transactions (e.g., every Monday)
    if tx[:weekly] && current_date.wday == 1 # Monday
      should_add = true
    end

    # Monthly transactions without specific day
    if tx[:monthly] && current_date.day == 15 # Middle of month for monthly without specific day
      should_add = true
    end

    # Apply probability filter
    should_add = should_add && (rand <= tx[:probability])

    if should_add
      account = account_objects[tx[:account]]
      category = category_objects[tx[:category]]

      # Calculate amount with variance
      final_amount = tx[:amount]
      if tx[:variance]
        variance_amount = rand(-tx[:variance]..tx[:variance])
        # For negative amounts, make sure variance doesn't flip the sign
        if tx[:amount] < 0
          final_amount = [tx[:amount] - variance_amount.abs, tx[:amount] + variance_amount.abs].min
        else
          final_amount = [tx[:amount] - variance_amount.abs, tx[:amount] + variance_amount.abs].max
        end
      end

      daily_transactions << {
        account: account,
        category: category,
        description: tx[:description],
        amount: final_amount,
        date: current_date
      }
    end
  end

  # Process occasional transactions for this day
  occasional_transactions.each do |tx|
    should_add = false

    # Check month-specific probabilities
    if tx[:months_probability] && tx[:months_probability][current_date.month]
      should_add = rand <= tx[:months_probability][current_date.month]
    end

    # Check annual probability (spread throughout the year)
    if tx[:annual_probability] && !should_add
      # Convert annual probability to daily
      daily_probability = tx[:annual_probability] / 365.0
      should_add = rand <= daily_probability
    end

    # Check frequency in months
    if tx[:frequency_months] && !should_add
      month_diff = (current_date.year * 12 + current_date.month) - (start_date.year * 12 + start_date.month)
      if month_diff % tx[:frequency_months] == 0 && current_date.day == 15 # Middle of the month
        should_add = true
      end
    end

    if should_add
      account = account_objects[tx[:account]]
      category = category_objects[tx[:category]]

      # Calculate amount with variance
      final_amount = tx[:amount]
      if tx[:variance]
        variance_amount = rand(-tx[:variance]..tx[:variance])
        # For negative amounts, make sure variance doesn't flip the sign
        if tx[:amount] < 0
          final_amount = [tx[:amount] - variance_amount.abs, tx[:amount] + variance_amount.abs].min
        else
          final_amount = [tx[:amount] - variance_amount.abs, tx[:amount] + variance_amount.abs].max
        end
      end

      daily_transactions << {
        account: account,
        category: category,
        description: tx[:description],
        amount: final_amount,
        date: current_date
      }
    end
  end

  # Create the transactions individually to trigger callbacks
  daily_transactions.each do |tx_data|
    transaction = Transaction.create!(
      account: tx_data[:account],
      category: tx_data[:category],
      description: tx_data[:description],
      amount: tx_data[:amount],
      date: tx_data[:date],
      created_at: tx_data[:date],
      updated_at: tx_data[:date]
    )
    transactions_count += 1

    if transactions_count % 100 == 0
      puts "  Created #{transactions_count} transactions so far..."
    end
  end

  # Move to next day
  current_date += 1.day
end

puts "Created #{transactions_count} transactions."

# Create budgets for each expense category
puts "Creating budgets..."
budget_categories = categories.reject { |c| c[:name] == "Income" || c[:name] == "Investments" }

budget_categories.each do |category_attrs|
  category = category_objects[category_attrs[:name]]

  # Calculate average monthly spending in this category
  monthly_spending = Transaction.joins(:account)
                                .where(category_id: category.id, accounts: { user_id: user.id })
                                .where("amount < 0")
                                .where("date >= ?", start_date)
                                .sum(:amount).abs / 12.0

  # Set budget slightly above average spending
  budget_amount = (monthly_spending * 1.1).round(2)

  # Skip if no spending in this category
  next if budget_amount == 0

  budget = user.budgets.find_or_create_by(category_id: category.id) do |b|
    b.amount = budget_amount
    b.period_start = Date.today.beginning_of_month
    b.period_end = Date.today.end_of_month
  end

  puts "  Created budget for #{category.name}: #{budget.amount}"
end

# Update account balances to match transactions
puts "Updating account balances based on transactions..."
account_objects.each do |name, account|
  # Sum all transactions for this account
  balance = Transaction.where(account_id: account.id).sum(:amount)

  # Update the account balance
  account.update(balance: balance)
  puts "  Updated #{name} balance to #{balance}"
end

# Create bank statements
puts "Creating bank statements..."

# Create monthly bank statements for each account
account_objects.each do |name, account|
  statement_date = start_date + 1.month

  while statement_date <= end_date
    period_start = statement_date - 1.month
    period_end = statement_date - 1.day

    # Get transactions in this period
    period_transactions = Transaction.where(account_id: account.id, date: period_start..period_end)

    # Calculate starting and ending balances
    starting_balance = Transaction.where(account_id: account.id, date: ...(period_start)).sum(:amount)
    ending_balance = starting_balance + period_transactions.sum(:amount)

    # Skip if no transactions in this period
    if period_transactions.any?
      statement = BankStatement.create!(
        account: account,
        statement_date: statement_date,
        start_date: period_start,
        end_date: period_end,
        starting_balance: starting_balance,
        ending_balance: ending_balance,
        reference: "STMT-#{account.name.gsub(/\s+/, '')}-#{period_end.strftime('%Y%m')}"
      )

      # Reconcile some transactions
      reconcile_count = [period_transactions.count / 2, 1].max
      reconcile_transactions = period_transactions.sample(reconcile_count)
      reconcile_transactions.each do |tx|
        tx.update(
          reconciled: true,
          reconciled_at: Time.current,
          bank_statement_id: statement.id
        )
      end

      puts "  Created bank statement for #{account.name}: #{period_start.strftime('%Y-%m-%d')} to #{period_end.strftime('%Y-%m-%d')}"

      # Lock older statements
      if statement_date < end_date - 2.months
        statement.update(locked: true)
      end
    end

    statement_date += 1.month
  end
end

# Create invoices
puts "Creating invoices..."

# Client data
clients = [
  { name: "Acme Corp", email: "billing@acmecorp.com", payment_rate: 0.9 },
  { name: "Globex Industries", email: "accounts@globex.com", payment_rate: 0.85 },
  { name: "Stark Enterprises", email: "payments@stark.com", payment_rate: 0.95 },
  { name: "Wayne Enterprises", email: "finance@wayne.com", payment_rate: 0.8 },
  { name: "Initech", email: "accounting@initech.com", payment_rate: 0.7 }
]

# Invoice data
invoice_count = 0
invoice_date = start_date

# Create historical invoices (about 2-3 per month)
while invoice_date <= end_date
  # Random number of invoices this month (2-3)
  num_invoices = rand(2..3)

  num_invoices.times do
    # Random client
    client = clients.sample

    # Random amount between $500 and $5000
    amount = (rand(500..5000) * 100).to_f / 100

    # Random issue date in this month
    issue_date = invoice_date + rand(0..27).days

    # Due date 30 days after issue date
    due_date = issue_date + 30.days

    # Determine status based on due date and payment rate
    status = if due_date > end_date
               "pending"
             elsif rand <= client[:payment_rate]
               "paid"
             elsif rand < 0.5
               "overdue"
             else
               "cancelled"
             end

    # Payment status
    payment_status = status == "paid" ? "paid" : "awaiting_payment"

    # Create the invoice
    invoice = user.invoices.create!(
      client_name: client[:name],
      client_email: client[:email],
      amount: amount,
      issue_date: issue_date,
      due_date: due_date,
      status: status,
      payment_status: payment_status,
      notes: "Professional services for #{issue_date.strftime('%B %Y')}",
      template: Invoice::TEMPLATES.sample
    )

    invoice_count += 1
    puts "  Created invoice ##{invoice_count} for #{client[:name]}: #{amount} (#{status})"
  end

  # Move to next month
  invoice_date = invoice_date.next_month
end

# Create a few recurring invoices
recurring_invoice_count = 0
clients.sample(2).each do |client|
  # Random amount between $500 and $2000
  amount = (rand(500..2000) * 100).to_f / 100

  # Issue date in the current month
  issue_date = Date.today.beginning_of_month + rand(1..10).days

  # Due date 30 days after issue date
  due_date = issue_date + 30.days

  # Create the recurring invoice
  invoice = user.invoices.create!(
    client_name: client[:name],
    client_email: client[:email],
    amount: amount,
    issue_date: issue_date,
    due_date: due_date,
    status: "pending",
    payment_status: "awaiting_payment",
    notes: "Monthly retainer services",
    template: Invoice::TEMPLATES.sample,
    recurring: true,
    recurring_interval: %w[monthly quarterly].sample,
    next_payment_date: due_date + 30.days
  )

  recurring_invoice_count += 1
  puts "  Created recurring invoice ##{recurring_invoice_count} for #{client[:name]}: #{amount} (monthly)"
end

puts "Created #{invoice_count} invoices and #{recurring_invoice_count} recurring invoices."

# Verify and fix any issues with journal entries
puts "Checking journal entries..."
journal_entries_count = JournalEntry.where(user_id: user.id).count
puts "Found #{journal_entries_count} journal entries."

if journal_entries_count == 0
  puts "No journal entries found. This may be because Transaction callbacks aren't creating them."
  puts "Let's manually create some journal entries for transactions..."

  # Create sample journal entries for the most recent 100 transactions
  recent_transactions = Transaction.joins(:account).where(accounts: { user_id: user.id }).order(date: :desc).limit(100)

  journal_entry_count = 0
  recent_transactions.each do |transaction|
    # Create a journal entry
    journal_entry = user.journal_entries.create!(
      date: transaction.date,
      reference: "TXN-#{transaction.id}",
      description: transaction.description,
      status: "posted",
      source_transaction_id: transaction.id
    )

    # Create journal lines based on transaction type
    if transaction.amount >= 0
      # Income transaction
      # Credit the income account (or use a default if no ledger account mapping exists)
      income_category = category_objects["Income"]

      journal_entry.journal_lines.create!(
        ledger_account_id: 1, # You may need to adjust this ID based on your database
        credit_amount: transaction.amount.abs,
        debit_amount: 0,
        description: "Income: #{transaction.description}"
      )

      # Debit the asset account
      journal_entry.journal_lines.create!(
        ledger_account_id: 2, # You may need to adjust this ID based on your database
        debit_amount: transaction.amount.abs,
        credit_amount: 0,
        description: "Income to: #{transaction.account.name}"
      )
    else
      # Expense transaction
      # Debit the expense account
      journal_entry.journal_lines.create!(
        ledger_account_id: 3, # You may need to adjust this ID based on your database
        debit_amount: transaction.amount.abs,
        credit_amount: 0,
        description: "Expense: #{transaction.description}"
      )

      # Credit the asset account
      journal_entry.journal_lines.create!(
        ledger_account_id: 2, # You may need to adjust this ID based on your database
        credit_amount: transaction.amount.abs,
        debit_amount: 0,
        description: "Expense from: #{transaction.account.name}"
      )
    end

    journal_entry_count += 1
    if journal_entry_count % 10 == 0
      puts "  Created #{journal_entry_count} journal entries so far..."
    end
  end

  puts "Created #{journal_entry_count} journal entries manually."
end

puts "Data seeding completed successfully!"
