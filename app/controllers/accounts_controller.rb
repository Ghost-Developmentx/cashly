class AccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account, only: [ :show, :edit, :update, :destroy ]
  def index
    @accounts = current_user.accounts.order(name: :asc)

    # Check integration status
  end

  def show
    @recent_transactions = @account.transactions.order(date: :desc).limit(10)

    # Get account metrics
    @balance = @account.balance

    # Calculate this month's activity
    month_start = Date.today.beginning_of_month
    month_end = Date.today.end_of_month

    @month_transactions = @account.transactions.where(date: month_start..month_end)
    @month_income = @month_transactions.where("amount > 0").sum(:amount)
    @month_expenses = @month_transactions.where("amount < 0").sum(:amount).abs
    @month_net = @month_income - @month_expenses
  end

  def new
    @account = Account.new
  end

  def edit
  end

  def create
    @account = current_user.accounts.build(account_params)

    respond_to do |format|
      if @account.save
        format.html { redirect_to @account, notice: "Account was successfully created." }
        format.json { render :show, status: :created, location: @account }
      else
        format.html { render :new }
        format.json { render json: @account.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    respond_to do |format|
      if @account.update(account_params)
        format.html { redirect_to @account, notice: "Account was successfully updated." }
        format.json { render :show, status: :ok, location: @account }
      else
        format.html { render :edit }
        format.json { render json: @account.errors, status: :unprocessable_content }
      end
    end
  end

  def destroy
    # Check if account has transactions before destroying
    if @account.transactions.exists?
      redirect_to account_url, alert: "Cannot delete account with transactions. Transfer or delete transactions first."
    else
      @account.destroy
      respond_to do |format|
        format.html { redirect_to accounts_url, notice: "Account was successfully destroyed." }
        format.json { head :no_content }
      end
    end
  end

  private

  def set_account
    @account = current_user.accounts.find(params[:id])
  end

  def account_params
    params.expect(account: [ :name, :account_type, :balance, :institution, :last_synced ])
  end
end
