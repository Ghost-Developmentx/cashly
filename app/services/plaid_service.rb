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

    ActiveRecord::Base.transaction do
      sync_accounts(access_token)
      sync_transaction_data(access_token, start_date, end_date)
    end

    true
  rescue Plaid::ApiError => e
    handle_plaid_error(e)
    false
  rescue StandardError => e
    Rails.logger.error "Unexpected error in sync: #{e.message}"
    false
  end

  private

  def sync_accounts(access_token)
    Rails.logger.info "[PlaidService] Syncing accounts for user #{@user.id}"

    accounts_response = @client.accounts_get(
      Plaid::AccountsGetRequest.new({ access_token: access_token })
    )

    accounts_response.accounts.each do |plaid_account|
      sync_single_account(plaid_account, accounts_response.item)
    end
  end

  def sync_single_account(plaid_account, item)
    account = @user.accounts.find_or_initialize_by(
      plaid_account_id: plaid_account.account_id
    )

    account.update!(
      name: plaid_account.name || "Unnamed Account",
      account_type: plaid_account.type || "other",
      balance: plaid_account.balances.current || 0,
      institution: item&.institution_id || "unknown",
      last_synced: Time.current
    )

    Rails.logger.info "[PlaidService] Synced account: #{account.name} (#{account.id})"
  rescue StandardError => e
    Rails.logger.error "[PlaidService] Failed to sync account #{plaid_account.account_id}: #{e.message}"
  end

  def sync_transaction_data(access_token, start_date, end_date)
    Rails.logger.info "[PlaidService] Syncing transactions from #{start_date} to #{end_date}"

    request = Plaid::TransactionsGetRequest.new(
      {
        access_token: access_token,
        start_date: start_date.to_s,
        end_date: end_date.to_s
      }
    )

    response = @client.transactions_get(request)
    process_transactions(response.transactions)
  end

  def process_transactions(transactions)
    Rails.logger.info "[PlaidService] Processing #{transactions.size} transactions"

    transactions.each do |plaid_transaction|
      process_single_transaction(plaid_transaction)
    end
  end

  def process_single_transaction(plaid_transaction)
    # Skip if already exists
    return if Transaction.exists?(plaid_transaction_id: plaid_transaction.transaction_id)

    account = @user.accounts.find_by(plaid_account_id: plaid_transaction.account_id)
    return unless account

    transaction = create_transaction_from_plaid(account, plaid_transaction)
    categorize_transaction(transaction) if transaction.persisted?
  rescue StandardError => e
    Rails.logger.error "[PlaidService] Failed to process transaction #{plaid_transaction.transaction_id}: #{e.message}"
  end

  def create_transaction_from_plaid(account, plaid_transaction)
    account.transactions.create!(
      date: plaid_transaction.date,
      amount: plaid_transaction.amount * -1, # Plaid uses opposite sign convention
      description: plaid_transaction.name,
      plaid_transaction_id: plaid_transaction.transaction_id,
      category: find_or_create_default_category,
      recurring: false
    )
  end

  def find_or_create_default_category
    Category.find_or_create_by(name: "Uncategorized") do |cat|
      cat.description = "Default category for uncategorized transactions"
    end
  end

  def categorize_transaction(transaction)
    CategorizeTransactionsJob.perform_later(transaction.id)
  end

  def handle_plaid_error(error)
    Rails.logger.error "[PlaidService] Plaid API Error: #{error.error_code} - #{error.error_message}"

    case error.error_code
    when "ITEM_LOGIN_REQUIRED"
      # Handle re-authentication needed
      notify_user_reauth_needed
    when "RATE_LIMIT_EXCEEDED"
      # Handle rate limiting
      Rails.logger.warn "[PlaidService] Rate limit exceeded, will retry later"
    else
      # Generic error handling
      Rails.logger.error "[PlaidService] Unhandled Plaid error: #{error.inspect}"
    end
  end

  def notify_user_reauth_needed
    # This could send an email or create a notification
    Rails.logger.warn "[PlaidService] User #{@user.id} needs to re-authenticate bank connection"
  end
end
