require "plaid"

class PlaidService
  def initialize(user)
    @user = user
    @client = Plaid::Client.new(
      env: Rails.env.production? ? :production : :sandbox,
      client_id: ENV["PLAID_CLIENT_ID"],
      secret: ENV["PLAID_SECRET"],
      public_key: ENV["PLAID_PUBLIC_KEY"],
    )
  end

  def create_link_token
    response = @client.link_token.create(
      user: {
        client_user_id: @user.id.to_s
      },
      client_name: "Cashly",
      products: [ "transactions" ],
      country_codes: [ "US" ],
      language: "en"
    )
    response.link_token
  end

  def exchange_public_token(public_token)
    exchange_response = @client.item.public_token.exchange(public_token)
    access_token = exchange_response.access_token
    item_id = exchange_response.item_id

    # Store these securely for user
    @user.update(plaid_item_id: item_id)
    PlaidToken.create(user: @user, access_token: access_token)

    item_id
  end

  def get_accounts
    access_token = @user.plaid_tokens.last&.access_token
    return [] unless access_token

    response = @client.accounts.get(access_token)
    response.accounts
  end

  def sync_transactions(start_date: 30.days.ago.to_date, end_date: Date.today)
    access_token = @user.plaid_tokens.last&.access_token
    return false unless access_token

    response = @client.transactions.get(
      access_token,
      start_date.to_s,
      end_date.to_s
    )

    # Process and save transactions
    response.transactions.each do |plaid_transaction|
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
        amount: plaid_transaction.amount * -1, # Plaid uses opposite sign convention
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
  end
end
