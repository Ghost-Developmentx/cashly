require "net/http"
require "uri"
require "json"


class AiService
  AI_SERVICE_URL = ENV["AI_SERVICE_URL"] || "http://localhost:5000"

  # Forecast cash flow based on historical transactions
  def self.forecast_cash_flow(user_id, transactions, days = 30)
    endpoint = "#{AI_SERVICE_URL}/forecast/cash_flow"

    formatted_transactions = transactions.map do |t|
      {
        date: t.date.to_s,
        amount: t.amount.to_f,
        category: t.category&.name || "uncategorized"
      }
    end

    payload = {
      user_id: user_id,
      transactions: formatted_transactions,
      forecast_days: days
    }

    make_request(endpoint, payload)
  end

  # Categorize transaction based on its description and amount
  def self.categorize_transaction(description, amount, date)
    endpoint = "#{AI_SERVICE_URL}/categorize/transaction"

    payload = {
      description: description,
      amount: amount.to_f,
      date: date.to_s
    }

    make_request(endpoint, payload)
  end

  # Generate budget recommendations based on transactions and income
  def self.generate_budget(user_id, transactions, income)
    endpoint = "#{AI_SERVICE_URL}/generate/budget"

    # Format transactions for AI service
    formatted_transactions = transactions.map do |t|
      {
        date: t.date.to_s,
        amount: t.amount.to_f,
        category: t.category&.name || "uncategorized"
      }
    end
    payload = {
      user_id: user_id,
      transactions: formatted_transactions,
      income: income.to_f
    }

    make_request(endpoint, payload)
  end

  # Analyze financial trends
  def self.analyze_trends(user_id, transactions, period = "3m")
    endpoint = "#{AI_SERVICE_URL}/analyze/trends"

    formatted_transactions = transactions.map do |t|
      {
        date: t.date.to_s,
        amount: t.amount.to_f,
        category: t.category&.name || "uncategorized"
      }
    end
    payload = {
      user_id: user_id,
      transactions: formatted_transactions,
      period: period
    }

    make_request(endpoint, payload)
  end

  private

  def self.make_request(endpoint, payload)
    uri = URI.parse(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
    request.body = payload.to_json

    begin
      response = http.request(request)

      if response.code.to_i == 200
        JSON.parse(response.body)
      else
        { error: "API request failed with status: #{response.code}: #{response.body}" }
      end
    rescue StandardError => e
      { error: "Failed to connect to AI service: #{e.message}" }
    end
  end
end
