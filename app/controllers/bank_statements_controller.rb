class BankStatementsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bank_statement, only: [ :show, :edit, :update, :destroy, :reconcile ]
  before_action :set_account_from_params, only: [ :index, :new, :create ]
  before_action :set_account_from_statement, only: [ :show, :edit, :update, :destroy ]


  def index
    @bank_statements = @account.bank_statements.recent_first.page(params[:page]).per(20)
  end

  def show
    @transactions = @bank_statement.transactions.order(date: :desc)
    @reconciled_transactions = @transactions.reconciled
    @unreconciled_transactions = @transactions.unreconciled

    # Calculate available transactions for reconciliation
    statement_period = @bank_statement.start_date..@bank_statement.end_date
    @available_transactions = @bank_statement.account.transactions
                                             .unreconciled
                                             .where(date: statement_period)
                                             .order(date: :desc)
  end

  def new
    @bank_statement = @account.bank_statements.new
  end

  def create
    @bank_statement = @account.bank_statements.new(bank_statement_params)

    if @bank_statement.save
      redirect_to account_bank_statement_path(@account, @bank_statement), notice: "Bank statement was successfully created."
    else
      render :new
    end
  end

  def edit
    # Block editing of locked statements
    if @bank_statement.locked?
      redirect_to account_bank_statement_path(@bank_statement.account, @bank_statement),
                  alert: "This bank statement is locked and cannot be edited."
      return
    end
  end

  def update
    # Block updating of locked statements
    if @bank_statement.locked?
      redirect_to account_bank_statement_path(@bank_statement.account, @bank_statement),
                  alert: "This bank statement is locked and cannot be updated."
      return
    end

    if @bank_statement.update(bank_statement_params)
      redirect_to account_bank_statement_path(@bank_statement.account, @bank_statement),
                  notice: "Bank statement was successfully updated."
    else
      render :edit
    end
  end

  def destroy
    # Block deletion of locked statements or statements with reconciled transactions
    if @bank_statement.locked?
      redirect_to account_bank_statement_path(@bank_statement.account, @bank_statement),
                  alert: "This bank statement is locked and cannot be deleted."
      return
    end

    if @bank_statement.reconciled?
      redirect_to account_bank_statement_path(@bank_statement.account, @bank_statement),
                  alert: "This bank statement has reconciled transactions and cannot be deleted."
      return
    end

    account = @bank_statement.account
    @bank_statement.destroy
    redirect_to account_bank_statements_path(account), notice: "Bank statement was successfully deleted."
  end

  def reconcile
    @transaction = Transaction.find(params[:transaction_id])

    # Block reconciliation if statement is locked
    if @bank_statement.locked?
      respond_to do |format|
        format.html {
          redirect_to account_bank_statement_path(@bank_statement.account, @bank_statement),
                      alert: "This bank statement is locked and cannot be modified."
        }
        format.json { render json: { success: false, errors: [ "Statement is locked and cannot be modified" ] } }
      end
      return
    end

    # Store transaction amount before reconciling for response
    transaction_amount = @transaction.amount

    if @transaction.reconcile(@bank_statement.id, params[:notes])
      respond_to do |format|
        format.html { redirect_to account_bank_statement_path(@bank_statement.account, @bank_statement) }
        format.json {
          render json: {
            success: true,
            transaction: {
              id: @transaction.id,
              amount: transaction_amount
            },
            summary: {
              reconciled_count: @bank_statement.transactions.where(reconciled: true).count,
              unreconciled_count: @bank_statement.transactions.where(reconciled: false).count,
              difference: @bank_statement.reconciliation_difference
            }
          }
        }
      end
    else
      respond_to do |format|
        format.html {
          redirect_to account_bank_statement_path(@bank_statement.account, @bank_statement),
                      alert: "Failed to reconcile transaction: #{@transaction.errors.full_messages.join(', ')}"
        }
        format.json { render json: { success: false, errors: @transaction.errors.full_messages } }
      end
    end
  end

  def unreconcile
    @transaction = Transaction.find(params[:transaction_id])
    @bank_statement = BankStatement.find(@transaction.statement_id)

    if @transaction.unreconcile
      respond_to do |format|
        format.html { redirect_to account_bank_statement_path(@bank_statement.account, @bank_statement) }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html {
          redirect_to account_bank_statement_path(@bank_statement.account, @bank_statement),
                      alert: "Failed to unreconcile transaction."
        }
        format.json { render json: { success: false, errors: @transaction.errors.full_messages } }
      end
    end
  end

  private

  def set_bank_statement
    @bank_statement = BankStatement.find(params[:id])
  end

  def set_account_from_params
    @account = current_user.accounts.find(params[:account_id])
  end

  def set_account_from_statement
    @account = @bank_statement.account
    # Optional: Ensure the account belongs to the current user
    redirect_to accounts_path, alert: "You don't have access to this account" unless current_user.accounts.include?(@account)
  end

  def bank_statement_params
    params.require(:bank_statement).permit(
      :statement_date, :start_date, :end_date,
      :starting_balance, :ending_balance,
      :statement_number, :reference, :notes,
      :file_path, :locked
    )
  end
end
