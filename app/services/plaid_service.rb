require "plaid"

class PlaidService
  def initialize(user)
    @user = user

    configuration = Plaid::Configuration.new
    configuration.server_index = Rails.env.production? ?
                                   Plaid::Configuration::Environment["production"] :
                                   Plaid::Configuration::Environment["sandbox"]

    configuration.api_key["PLAID-CLIENT-ID"] = ENV["PLAID_CLIENT_ID"]
    configuration.api_key["PLAID-SECRET"] = ENV["PLAID_SECRET"]

    api_client = Plaid::ApiClient.new(configuration)
    @client = Plaid::PlaidApi.new(api_client)
  end

  def create_link_token
    link_token_request = Plaid::LinkTokenCreateRequest.new({
                                                             user: { client_user_id: @user.id.to_s },
                                                             client_name: "Cashly",
                                                             products: [ "transactions" ],
                                                             country_codes: [ "US" ],
                                                             language: "en"
                                                           })

    begin
      link_token_response = @client.link_token_create(link_token_request)
      link_token_response.link_token
    rescue Plaid::ApiError => e
      Rails.logger.error "Error creating link token: #{e.response_body}"
      nil
    end
  end

  def exchange_public_token(public_token)
    exchange_request = Plaid::ItemPublicTokenExchangeRequest.new(
      { public_token: public_token }
    )

    begin
      exchange_response = @client.item_public_token_exchange(exchange_request)
      access_token = exchange_response.access_token
      item_id = exchange_response.item_id

      # Store these securely for user
      PlaidToken.create(user: @user, access_token: access_token, item_id: item_id)

      item_id
    rescue Plaid::ApiError => e
      Rails.logger.error "Error exchanging public token: #{e.response_body}"
      nil
    end
  end

  def get_accounts
    access_token = @user.plaid_tokens.last&.access_token
    return [] unless access_token

    begin
      request = Plaid::AccountsGetRequest.new({ access_token: access_token })
      response = @client.accounts_get(request)
      response.accounts
    rescue Plaid::ApiError => e
      Rails.logger.error "Error getting accounts: #{e.response_body}"
      []
    end
  end

  def sync_transactions(start_date: 30.days.ago.to_date, end_date: Date.today)
    access_token = @user.plaid_tokens.last&.access_token
    return false unless access_token

    begin
      # STEP 1: First, get and save the accounts
      Rails.logger.info "Fetching accounts for user #{@user.id} with token ending in ...#{access_token[-4..]}"

      # Get accounts response which includes both accounts and institution info
      accounts_request = Plaid::AccountsGetRequest.new({ access_token: access_token })
      accounts_response = @client.accounts_get(accounts_request)
      accounts = accounts_response.accounts

      # Get the institution ID from the item
      item_id = accounts_response.item&.item_id
      institution_id = accounts_response.item&.institution_id || "unknown_institution"

      if accounts.empty?
        Rails.logger.warn "No accounts found for user #{@user.id}"
        return false
      end

      # Log the number of accounts found
      Rails.logger.info "Found #{accounts.size} accounts for user #{@user.id}"

      # Save all accounts first
      plaid_accounts = {}
      accounts.each do |plaid_account|
        begin
          # Find or create the account
          account = @user.accounts.find_or_initialize_by(plaid_account_id: plaid_account.account_id)

          # Update account details
          account.name = plaid_account.name || "Unnamed Account"
          account.account_type = plaid_account.type || "other"
          account.balance = plaid_account.balances.current || 0
          account.institution = institution_id # Use the institution ID from the item
          account.last_synced = Time.now

          # Add additional error checking and logging
          Rails.logger.info "Saving account: #{account.name} (#{plaid_account.account_id})"

          if account.save
            Rails.logger.info "Successfully saved account #{account.id}"
            plaid_accounts[plaid_account.account_id] = account
          else
            Rails.logger.error "Failed to save account: #{account.errors.full_messages.join(', ')}"
          end
        rescue => e
          Rails.logger.error "Error saving account #{plaid_account.account_id}: #{e.message}"
        end
      end

      # STEP 2: Now fetch transactions
      Rails.logger.info "Fetching transactions from #{start_date} to #{end_date}"
      request = Plaid::TransactionsGetRequest.new(
        {
          access_token: access_token,
          start_date: start_date.to_s,
          end_date: end_date.to_s
        }
      )
      response = @client.transactions_get(request)
      transactions = response.transactions

      # Log transaction count
      Rails.logger.info "Found #{transactions.size} transactions"

      uncategorized_category = Category.find_or_create_by(name: "Uncategorized") do |cat|
        cat.description = "Default category for uncategorized transactions"
        cat.parent_category_id = nil
      end

      # Track stats for logging
      created_count = 0
      skipped_count = 0
      error_count = 0

      # Process and save transactions
      transactions.each do |plaid_transaction|
        # Skip if transaction already exists
        if Transaction.exists?(plaid_transaction_id: plaid_transaction.transaction_id)
          skipped_count += 1
          next
        end

        # Get the account (should have been created above)
        account = plaid_accounts[plaid_transaction.account_id]

        unless account
          Rails.logger.error "Account not found for transaction #{plaid_transaction.transaction_id} (account_id: #{plaid_transaction.account_id})"
          error_count += 1
          next
        end

        # Create transaction
        transaction = account.transactions.new(
          date: plaid_transaction.date,
          amount: plaid_transaction.amount * -1, # Plaid uses opposite sign convention
          description: plaid_transaction.name,
          plaid_transaction_id: plaid_transaction.transaction_id,
          category_id: uncategorized_category.id,
          recurring: false,
        )

        if transaction.save
          created_count += 1

          # Categorize via AI service (if available)
          begin
            category_response = AiService.categorize_transaction(
              transaction.description,
              transaction.amount,
              transaction.date
            )

            if category_response.is_a?(Hash) && !category_response[:error]
              category_name = category_response["category"]
              category = Category.find_or_create_by(name: category_name)
              transaction.update(category: category)
            end
          rescue => e
            Rails.logger.error "Error categorizing transaction: #{e.message}"
          end
        else
          Rails.logger.error "Failed to save transaction: #{transaction.errors.full_messages.join(', ')}"
          error_count += 1
        end
      end

      Rails.logger.info "Sync complete: Created #{created_count} transactions, Skipped #{skipped_count}, Errors #{error_count}"
      true
    rescue => e
      Rails.logger.error "Unexpected error syncing transactions: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end
end
