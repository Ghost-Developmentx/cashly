class ReportsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Just a landing page for reports
  end

  def trial_balance
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today.end_of_month

    # Get all posted journal entries in the date range
    journal_entries = current_user.journal_entries
                                  .where(status: JournalEntry::POSTED)
                                  .where(date: @start_date..@end_date)
                                  .includes(journal_lines: :ledger_account)

    # Group journal lines by account, calculate totals
    @trial_balance = {}

    journal_entries.flat_map(&:journal_lines).each do |line|
      account = line.ledger_account
      @trial_balance[account] ||= { debit: 0, credit: 0 }
      @trial_balance[account][:debit] += line.debit_amount
      @trial_balance[account][:credit] += line.credit_amount
    end

    # Sort accounts by code
    @trial_balance = @trial_balance.sort_by { |account, _| account.code }.to_h

    # Calculate totals
    @total_debits = @trial_balance.sum { |_, amounts| amounts[:debit] }
    @total_credits = @trial_balance.sum { |_, amounts| amounts[:credit] }
  end

  def income_statement
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today.end_of_month

    # Get all posted journal entries in the date range
    journal_entries = current_user.journal_entries
                                  .where(status: JournalEntry::POSTED)
                                  .where(date: @start_date..@end_date)
                                  .includes(journal_lines: :ledger_account)

    # Gather revenue accounts
    @revenue_accounts = {}
    # Gather expense accounts
    @expense_accounts = {}

    journal_entries.flat_map(&:journal_lines).each do |line|
      account = line.ledger_account

      if account.account_type == "revenue"
        @revenue_accounts[account] ||= { debit: 0, credit: 0 }
        @revenue_accounts[account][:debit] += line.debit_amount
        @revenue_accounts[account][:credit] += line.credit_amount
      elsif account.account_type == "expense"
        @expense_accounts[account] ||= { debit: 0, credit: 0 }
        @expense_accounts[account][:debit] += line.debit_amount
        @expense_accounts[account][:credit] += line.credit_amount
      end
    end

    # Sort accounts by code
    @revenue_accounts = @revenue_accounts.sort_by { |account, _| account.code }.to_h
    @expense_accounts = @expense_accounts.sort_by { |account, _| account.code }.to_h

    # Calculate revenue total (credits - debits for revenue accounts)
    @total_revenue = @revenue_accounts.sum { |_, amounts| amounts[:credit] - amounts[:debit] }

    # Calculate expense total (debits - credits for expense accounts)
    @total_expenses = @expense_accounts.sum { |_, amounts| amounts[:debit] - amounts[:credit] }

    # Calculate net income
    @net_income = @total_revenue - @total_expenses
  end

  def balance_sheet
    @date = params[:date] ? Date.parse(params[:date]) : Date.today

    # Get all posted journal entries up to the date
    journal_entries = current_user.journal_entries
                                  .where(status: JournalEntry::POSTED)
                                  .where("date <= ?", @date)
                                  .includes(journal_lines: :ledger_account)

    # Gather asset accounts
    @asset_accounts = {}
    # Gather liability accounts
    @liability_accounts = {}
    # Gather equity accounts
    @equity_accounts = {}

    journal_entries.flat_map(&:journal_lines).each do |line|
      account = line.ledger_account

      case account.account_type
      when "asset"
        @asset_accounts[account] ||= { debit: 0, credit: 0 }
        @asset_accounts[account][:debit] += line.debit_amount
        @asset_accounts[account][:credit] += line.credit_amount
      when "liability"
        @liability_accounts[account] ||= { debit: 0, credit: 0 }
        @liability_accounts[account][:debit] += line.debit_amount
        @liability_accounts[account][:credit] += line.credit_amount
      when "equity"
        @equity_accounts[account] ||= { debit: 0, credit: 0 }
        @equity_accounts[account][:debit] += line.debit_amount
        @equity_accounts[account][:credit] += line.credit_amount
      end
    end

    # Sort accounts by code
    @asset_accounts = @asset_accounts.sort_by { |account, _| account.code }.to_h
    @liability_accounts = @liability_accounts.sort_by { |account, _| account.code }.to_h
    @equity_accounts = @equity_accounts.sort_by { |account, _| account.code }.to_h

    # Calculate asset total (debits - credits for asset accounts)
    @total_assets = @asset_accounts.sum { |_, amounts| amounts[:debit] - amounts[:credit] }

    # Calculate liability total (credits - debits for liability accounts)
    @total_liabilities = @liability_accounts.sum { |_, amounts| amounts[:credit] - amounts[:debit] }

    # Calculate equity total (credits - debits for equity accounts)
    @total_equity = @equity_accounts.sum { |_, amounts| amounts[:credit] - amounts[:debit] }

    # Should balance: total_assets = total_liabilities + total_equity
    @is_balanced = (@total_assets - (@total_liabilities + @total_equity)).abs < 0.01
  end

  def cash_flow_statement
    @start_date = params[:start_date] ? Date.parse(params[:start_date]) : Date.today.beginning_of_month
    @end_date = params[:end_date] ? Date.parse(params[:end_date]) : Date.today.end_of_month

    # Get all posted journal entries in the date range
    journal_entries = current_user.journal_entries
                                  .where(status: JournalEntry::POSTED)
                                  .where(date: @start_date..@end_date)
                                  .includes(journal_lines: :ledger_account)

    # Initialize cash flow categories
    @operating_activities = {}
    @investing_activities = {}
    @financing_activities = {}

    # Map account subtypes to cash flow categories
    # This mapping can be customized based on your chart of accounts structure
    operating_subtypes = %w[current_asset current_liability revenue expense]
    investing_subtypes = %w[fixed_asset non_current_asset]
    financing_subtypes = %w[non_current_liability owner_equity]

    # Process journal lines
    journal_entries.flat_map(&:journal_lines).each do |line|
      account = line.ledger_account
      subtype = account.account_subtype

      # Skip cash accounts (we'll calculate net change in cash separately)
      next if account.code.start_with?("100") # Assuming 100x are cash accounts

      # Determine where this activity belongs
      if subtype.blank? || operating_subtypes.include?(subtype)
        # For operating activities, include revenue and expense accounts
        if account.account_type == "revenue" || account.account_type == "expense"
          @operating_activities[account] ||= { debit: 0, credit: 0 }
          @operating_activities[account][:debit] += line.debit_amount
          @operating_activities[account][:credit] += line.credit_amount
          # Also include current assets/liabilities as operating (except cash)
        elsif subtype == "current_asset" || subtype == "current_liability"
          @operating_activities[account] ||= { debit: 0, credit: 0 }
          @operating_activities[account][:debit] += line.debit_amount
          @operating_activities[account][:credit] += line.credit_amount
        end
      elsif investing_subtypes.include?(subtype)
        @investing_activities[account] ||= { debit: 0, credit: 0 }
        @investing_activities[account][:debit] += line.debit_amount
        @investing_activities[account][:credit] += line.credit_amount
      elsif financing_subtypes.include?(subtype)
        @financing_activities[account] ||= { debit: 0, credit: 0 }
        @financing_activities[account][:debit] += line.debit_amount
        @financing_activities[account][:credit] += line.credit_amount
      end
    end

    # Sort accounts by code
    @operating_activities = @operating_activities.sort_by { |account, _| account.code }.to_h
    @investing_activities = @investing_activities.sort_by { |account, _| account.code }.to_h
    @financing_activities = @financing_activities.sort_by { |account, _| account.code }.to_h

    # Calculate totals for each section
    # For operating activities, revenue increases cash, expenses decrease cash
    @total_operating = 0
    @operating_activities.each do |account, amounts|
      if account.account_type == "revenue"
        # Revenue: credits increase cash
        @total_operating += (amounts[:credit] - amounts[:debit])
      elsif account.account_type == "expense"
        # Expenses: debits decrease cash
        @total_operating -= (amounts[:debit] - amounts[:credit])
      else
        # For assets and liabilities, we need the net change
        # Increases in assets decrease cash, increases in liabilities increase cash
        net_change = if account.account_type == "asset"
                       amounts[:debit] - amounts[:credit] # Net increase in asset
        else
                       amounts[:credit] - amounts[:debit] # Net increase in liability
        end

        # Asset increases (positive net_change) decrease cash flow
        # Liability increases (positive net_change) increase cash flow
        @total_operating += account.account_type == "asset" ? -net_change : net_change
      end
    end

    # For investing and financing, calculate based on account normal balances
    @total_investing = 0
    @investing_activities.each do |account, amounts|
      # For assets, an increase (debit) is a use of cash (negative)
      # For liabilities, an increase (credit) is a source of cash (positive)
      if account.account_type == "asset"
        @total_investing -= (amounts[:debit] - amounts[:credit])
      else
        @total_investing += (amounts[:credit] - amounts[:debit])
      end
    end

    @total_financing = 0
    @financing_activities.each do |account, amounts|
      # For equity/liabilities, a credit increases cash
      @total_financing += (amounts[:credit] - amounts[:debit])
    end

    # Calculate net change in cash
    @net_cash_change = @total_operating + @total_investing + @total_financing

    # Get beginning and ending cash balances
    cash_accounts = LedgerAccount.where("code LIKE '100%'")

    # For beginning balance, get journal entries up to start_date - 1
    beginning_entries = current_user.journal_entries
                                    .where(status: JournalEntry::POSTED)
                                    .where("date < ?", @start_date)
                                    .includes(journal_lines: :ledger_account)

    @beginning_cash = 0
    beginning_entries.flat_map(&:journal_lines).each do |line|
      next unless cash_accounts.include?(line.ledger_account)
      @beginning_cash += line.debit_amount - line.credit_amount
    end

    # Ending cash is beginning cash plus net change
    @ending_cash = @beginning_cash + @net_cash_change
  end
end
