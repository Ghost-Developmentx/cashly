# app/controllers/imports_controller.rb
require "csv"

class ImportsController < ApplicationController
  before_action :authenticate_user!

  def new
    @accounts = current_user.accounts
  end

  def create
    if params[:file].nil?
      redirect_to new_import_path, alert: "Please select a file to import."
      return
    end

    account = current_user.accounts.find(params[:account_id])
    file = params[:file]

    if File.extname(file.original_filename) != ".csv"
      redirect_to new_import_path, alert: "Please upload a CSV file."
      return
    end

    begin
      # Process the CSV file
      success_count = 0
      failed_transactions = []

      CSV.foreach(file.path, headers: true) do |row|
        # Extract data from CSV row
        date = parse_date(row["date"] || row["Date"])
        description = row["description"] || row["Description"] || row["name"] || row["Name"] || ""
        amount = parse_amount(row["amount"] || row["Amount"])

        # Skip rows with missing essential data
        next if date.nil? || amount.nil?

        # Create transaction
        transaction = account.transactions.new(
          date: date,
          description: description,
          amount: amount
        )

        # Try to categorize using AI if we have a description
        if description.present?
          category_response = AiService.categorize_transaction(
            description,
            amount,
            date
          )

          if category_response.is_a?(Hash) && !category_response[:error]
            category_name = category_response["category"]
            category = Category.find_or_create_by(name: category_name)
            transaction.category = category
          end
        end

        # Save the transaction
        if transaction.save
          success_count += 1
        else
          failed_transactions << {
            row: row.to_h,
            errors: transaction.errors.full_messages.join(", ")
          }
        end
      end

      flash[:notice] = "Successfully imported #{success_count} transactions."

      if failed_transactions.any?
        flash[:alert] = "Failed to import #{failed_transactions.size} transactions due to errors."
        session[:failed_imports] = failed_transactions
      end

      redirect_to transactions_path

    rescue => e
      redirect_to new_import_path, alert: "Error importing file: #{e.message}"
    end
  end

  def failed
    @failed_imports = session[:failed_imports] || []
  end

  private

  def parse_date(date_str)
    return nil if date_str.blank?

    # Try different date formats
    begin
      # Try standard formats first
      Date.parse(date_str)
    rescue
      # Try MM/DD/YYYY format
      if date_str =~ %r{^\d{1,2}/\d{1,2}/\d{4}$}
        parts = date_str.split("/")
        return Date.new(parts[2].to_i, parts[0].to_i, parts[1].to_i)
      end

      # Try DD/MM/YYYY format
      if date_str =~ %r{^\d{1,2}/\d{1,2}/\d{4}$}
        parts = date_str.split("/")
        return Date.new(parts[2].to_i, parts[1].to_i, parts[0].to_i)
      end

      # If all attempts fail, return nil
      nil
    end
  end

  def parse_amount(amount_str)
    return nil if amount_str.blank?

    # Remove currency symbols, commas, etc. and convert to float
    amount_str = amount_str.gsub(/[^\d.-]/, "")

    # Handle European format (comma as decimal separator)
    if amount_str.include?(",") && !amount_str.include?(".")
      amount_str = amount_str.gsub(",", ".")
    end

    begin
      Float(amount_str)
    rescue
      nil
    end
  end
end
