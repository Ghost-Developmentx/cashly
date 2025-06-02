module Fin
  class AiClient < BaseService
    AI_SERVICE_URL = ENV["AI_SERVICE_URL"] || "http://localhost:8000"

    def initialize
      @endpoint = "#{AI_SERVICE_URL}/api/v1/fin/conversations/query"
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
      normalized_context = sanitize_user_context(user_context, user_id)

      {
        user_id: user_id.to_s,
        query: query,
        transactions: transactions,
        conversation_history: conversation_history,
        user_context: normalized_context
      }
    end

    def sanitize_user_context(ctx, fallback_user_id = nil)
      return { "user_id" => fallback_user_id.to_s } unless ctx.is_a?(Hash)

      sanitized = ctx.deep_dup

      # Ensure user_id is always a string
      if sanitized["user_id"].is_a?(Hash)
        sanitized["user_id"] = sanitized["user_id"]["id"].to_s if sanitized["user_id"]["id"]
      elsif sanitized["user_id"]
        sanitized["user_id"] = sanitized["user_id"].to_s
      elsif fallback_user_id
        sanitized["user_id"] = fallback_user_id.to_s
      else
        log_warn "⚠️ user_context missing user_id and no fallback available"
      end

      sanitized
    end

    def log_request_details(payload)
      log_info "Making request to: #{@endpoint}"
      log_info "Payload keys: #{payload.keys}"
      log_info "Transactions count: #{payload[:transactions]&.length || 0}"
      log_info "User context accounts: #{payload[:user_context]&.dig("accounts")&.length || 0}"
      log_info "User context user_id: #{payload[:user_context]["user_id"]}"

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

