# lib/tasks/chart_of_accounts.rake
namespace :accounting do
  desc "Initialize standard Chart of Accounts"
  task initialize_coa: :environment do
    # Clear existing ledger accounts if the --force flag is passed
    if ENV["FORCE"] == "true"
      puts "Clearing existing ledger accounts..."
      LedgerAccount.destroy_all
    elsif LedgerAccount.count > 0
      puts "Error: Ledger accounts already exist. Use FORCE=true to override."
      exit 1
    end

    # Load the seed data
    require Rails.root.join("db", "seeds", "chart_of_accounts")

    puts "Initialized Chart of Accounts with #{LedgerAccount.count} accounts."
  end

  desc "Map categories to appropriate ledger accounts"
  task map_categories: :environment do
    # Check if we have ledger accounts
    if LedgerAccount.count == 0
      puts "Error: No ledger accounts found. Please run 'rake accounting:initialize_coa' first."
      exit 1
    end

    # Get all categories
    categories = Category.all

    if categories.empty?
      puts "No categories found to map."
      exit 0
    end

    puts "Mapping #{categories.count} categories to ledger accounts..."

    # Default expense account for most categories
    default_expense_account = LedgerAccount.expenses.where("name ILIKE ?", "%operating expense%").first ||
      LedgerAccount.expenses.first

    # Default revenue account for income categories
    default_revenue_account = LedgerAccount.revenue.where("name ILIKE ?", "%sales%").first ||
      LedgerAccount.revenue.where("name ILIKE ?", "%operating%").first ||
      LedgerAccount.revenue.first

    # Clear existing mappings if the --force flag is passed
    if ENV["FORCE"] == "true"
      puts "Clearing existing category mappings..."
      CategoryAccountMapping.destroy_all
    end

    # Map each category
    categories.each do |category|
      # Skip if already mapped
      next if CategoryAccountMapping.exists?(category_id: category.id) && ENV["FORCE"] != "true"

      # Determine if income category
      is_income = category.name.downcase.include?("income") ||
        category.name.downcase.include?("revenue") ||
        category.name.downcase.include?("salary")

      # Select default account based on category type
      default_account = is_income ? default_revenue_account : default_expense_account

      # Try to find a more specific matching account
      if is_income
        specific_account = LedgerAccount.revenue.where("name ILIKE ?", "%#{category.name}%").first
      else
        specific_account = LedgerAccount.expenses.where("name ILIKE ?", "%#{category.name}%").first
      end

      # Use specific account if found, otherwise use default
      account_to_map = specific_account || default_account

      if account_to_map
        # Create or update the mapping
        mapping = CategoryAccountMapping.find_or_initialize_by(category_id: category.id)
        mapping.ledger_account = account_to_map
        if mapping.save
          puts "  Mapped category '#{category.name}' to '#{account_to_map.full_name}'"
        else
          puts "  Error mapping category '#{category.name}': #{mapping.errors.full_messages.join(', ')}"
        end
      else
        puts "  No suitable account found for category '#{category.name}'"
      end
    end

    puts "Finished mapping categories to ledger accounts."
  end

  desc "Initialize full accounting system (Chart of Accounts and category mappings)"
  task initialize: :environment do
    # Run both tasks
    Rake::Task["accounting:initialize_coa"].invoke
    Rake::Task["accounting:map_categories"].invoke
  end
end
