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
end
