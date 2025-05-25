module Fin
  class AiClient < BaseService
    AI_SERVICE_URL = ENV["AI_SERVICE_URL"] || "http://localhost:5000"

    def initialize
      @endpoint = "#{AI_SERVICE_URL}/fin/conversations/query"
    end

    def query(user_id:, query:, conversation_history: nil, transactions: [], user_context: {})
      payload = build_payload(user_id, query, conversation_history, transactions, user_context)

      log_request_details(payload)
      response = make_http_request(payload)
      log_response_details(response)

      response
    end

    private

    def build_payload(user_id, query, conversation_history, transactions, user_context)
      {
        user_id: user_id,
        query: query,
        transactions: transactions,
        conversation_history: conversation_history,
        user_context: user_context
      }
    end

    def log_request_details(payload)
      log_info "Making request to: #{@endpoint}"
      log_info "Payload keys: #{payload.keys}"
      log_info "Transactions count: #{payload[:transactions]&.length || 0}"
      log_info "User context accounts: #{payload[:user_context]&.dig(:accounts)&.length || 0}"

      if payload[:transactions]&.any?
        first_txn = payload[:transactions].first
        log_info "First transaction: #{first_txn}"
      end
    end

    def log_response_details(response)
      return unless response.is_a?(Hash)

      log_info "Response keys: #{response.keys}"
      log_info "Actions count: #{response['actions']&.length || 0}"
      log_info "Tool results count: #{response['tool_results']&.length || 0}"
    end

    def make_http_request(payload)
      uri = URI.parse(@endpoint)
      http = Net::HTTP.new(uri.host, uri.port)

      request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
      request.body = payload.to_json

      log_info "Request body size: #{request.body.length} characters"

      response = http.request(request)
      log_info "Response status: #{response.code}"

      if response.code.to_i == 200
        JSON.parse(response.body)
      else
        log_error "API request failed: #{response.code}: #{response.body}"
        { error: "API request failed with status: #{response.code}: #{response.body}" }
      end
    rescue StandardError => e
      log_error "Connection error: #{e.message}"
      { error: "Failed to connect to AI service: #{e.message}" }
    end
  end
end
