class CategoryAccountMappingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_category, only: [ :create, :update ]

  def index
    @categories = Category.includes(:ledger_accounts).order(:name)
    @ledger_accounts = LedgerAccount.active.order(:account_type, :name)
  end

  def create
    @mapping = CategoryAccountMapping.new(category_id: @category.id, ledger_account_id: params[:ledger_account_id])

    if @mapping.save
      redirect_to category_account_mappings_path, notice: "Category successfully mapped to account."
    else
      redirect_to category_account_mappings_path, alert: "Error mapping category to account: #{@mapping.errors.full_messages.join(', ')}"
    end
  end

  def update
    @mapping = CategoryAccountMapping.find_by(category_id: @category.id)

    if @mapping.update(ledger_account_id: params[:ledger_account_id])
      redirect_to category_account_mappings_path, notice: "Category mapping successfully updated."
    else
      redirect_to category_account_mappings_path, alert: "Error updating category mapping: #{@mapping.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    begin
      # Log parameters to help with debugging
      Rails.logger.debug "DESTROY PARAMS: #{params.inspect}"

      @mapping = CategoryAccountMapping.find(params[:id])

      # Log that we found the mapping
      Rails.logger.debug "FOUND MAPPING: #{@mapping.inspect}"

      if @mapping.destroy
        # Log successful destruction
        Rails.logger.debug "DESTROYED MAPPING SUCCESSFULLY"
        redirect_to category_account_mappings_path, notice: "Category mapping successfully removed."
      else
        # Log failure
        Rails.logger.debug "FAILED TO DESTROY MAPPING: #{@mapping.errors.full_messages.join(', ')}"
        redirect_to category_account_mappings_path, alert: "Error removing category mapping."
      end
    rescue => e
      # Log any exceptions
      Rails.logger.error "ERROR IN DESTROY: #{e.message}"
      redirect_to category_account_mappings_path, alert: "Error removing category mapping: #{e.message}"
    end
  end

  private

  def set_category
    @category = Category.find(params[:category_id])
  end
end
