class LedgerAccountsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ledger_account, only: [:show, :edit, :update, :toggle_active]

  def index
    @account_type = params[:account_type].presence

    # Base query for ledger accounts
    @ledger_accounts = LedgerAccount.all

    # Filter by account type if specified
    @ledger_accounts = @ledger_accounts.where(account_type: @account_type) if @account_type

    # Group by account type for navigation
    @account_types = LedgerAccount.pluck(:account_type).uniq.sort

    # Get root accounts for hierarchical display
    @root_accounts = @ledger_accounts.root_accounts
  end

  def show
    # Get all child accounts for hierarchical display
    @child_accounts = @ledger_account.child_accounts
  end

  def new
    @ledger_account = LedgerAccount.new
    @parent_account_id = params[:parent_account_id]
    @account_type = params[:account_type] || "expense"

    # Set the parent account if provided
    if @parent_account_id
      @parent_account = LedgerAccount.find(@parent_account_id)
      @ledger_account.parent_account = @parent_account
      @account_type = @parent_account.account_type
    end

    # Set default account type and balance based on type
    @ledger_account.account_type = @account_type
    @ledger_account.default_balance = default_balance_for_type(@account_type)
  end

  def create
    @ledger_account = LedgerAccount.new(ledger_account_params)

    if @ledger_account.save
      redirect_to ledger_account_path(@ledger_account), notice: "Account was successfully created."
    else
      @account_type = @ledger_account.account_type
      render :new
    end
  end

  def edit
  end

  def update
    if @ledger_account.update(ledger_account_params)
      redirect_to ledger_account_path(@ledger_account), notice: "Account was successfully updated."
    else
      render :edit
    end
  end

  def toggle_active
    @ledger_account.update(active: !@ledger_account.active)
    redirect_to ledger_account_path(@ledger_account), notice: "Account was #{@ledger_account.active? ? 'activated' : 'deactivated'}."
  end

  private

  def set_ledger_account
    @ledger_account = LedgerAccount.find(params[:id])
  end

  def ledger_account_params
    params.require(:ledger_account).permit(
      :name, :code, :account_type, :account_subtype,
      :description, :parent_account_id, :active, :default_balance, :display_order
    )
  end

  def default_balance_for_type(account_type)
    case account_type
    when "asset", "expense"
      "debit"
    when "liability", "equity", "revenue"
      "credit"
    else
      "debit"
    end
  end
end
