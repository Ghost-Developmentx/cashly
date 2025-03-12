require "plaid"

class PlaidService
  def initialize(user)
    @user = user

    configuration = Plaid::Configuration.new
    configuration.server_index = Rails.env.production? ?
                                   Plaid::Configuration::Environment["production"] :
                                   Plaid::Configuration::Environment["sandbox"]

    configuration.api_key["PLAID-CLIENT-ID"] = ENV["PLAID-CLIENT-ID"]
    configuration.api_key["PLAID-SECRET"] = ENV["PLAID-SECRET"]

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
      request = Plaid::TransactionsGetRequest.new(
        {
          access_token: access_token,
          start_date: start_date.to_s,
          end_date: end_date.to_s
        }
      )
      response = @client.transactions_get(request)
      transactions = response.transactions

      # Process and save transactions
      transactions.each do |plaid_transaction|
        # Find or create account
        account = @user.accounts.find_or_create_by(
          plaid_account_id: plaid_transaction.account_id
        ) do |acc|
          acc.name = "Imported Account"
          acc.account_type = "checking"
          acc.balance = 0
        end

        # Skip if transaction already exists
        next if Transaction.exists?(plaid_transaction_id: plaid_transaction.transaction_id)

        # Create transaction
        transaction = account.transactions.create(
          date: plaid_transaction.date,
          amount: plaid_transaction.amount * -1,
          description: plaid_transaction.name,
          plaid_transaction_id: plaid_transaction.transaction_id
        )

        # Categorize via AI service
        if transaction.persisted?
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
        end
      end

      true
    rescue Plaid::ApiError => e
      Rails.logger.error "Error syncing transactions: #{e.response_body}"
      false
    end
  end
end
