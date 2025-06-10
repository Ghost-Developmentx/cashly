module FinancialAI
  class AiClient
    AI_SERVICE_URL = ENV["AI_SERVICE_URL"] || "http://localhost:8000"

    def initialize
      @endpoint = "#{AI_SERVICE_URL}/api/v1/fin/conversations/query"
    end

    def query(user_id:, query:, conversation_history: nil, transactions: [], user_context: {})
      payload = build_payload(user_id, query, conversation_history, transactions, user_context)

      Rails.logger.info "[AiClient] Querying AI with user_id: #{user_id}"
      Rails.logger.debug "[AiClient] Payload: #{payload.to_json}" if Rails.env.development?

      response = make_request(payload)

      Rails.logger.info "[AiClient] Response received with #{response['tool_results']&.length || 0} tool results"

      response
    end

    private

    def build_payload(user_id, query, conversation_history, transactions, user_context)
      {
        user_id: user_id.to_s,
        query: query,
        transactions: transactions || [],
        conversation_history: conversation_history || [],
        user_context: normalize_user_context(user_context, user_id)
      }
    end

    def normalize_user_context(context, user_id)
      return { user_id: user_id.to_s } unless context.is_a?(Hash)

      context.deep_dup.tap do |ctx|
        ctx["user_id"] = user_id.to_s
      end
    end

    def make_request(payload)
      uri = URI.parse(@endpoint)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 30
      http.open_timeout = 10

      request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
      request.body = payload.to_json

      response = http.request(request)

      if response.code.to_i == 200
        JSON.parse(response.body)
      else
        Rails.logger.error "[AiClient] API request failed: #{response.code} - #{response.body}"
        { error: "AI service request failed: #{response.code}" }
      end
    rescue StandardError => e
      Rails.logger.error "[AiClient] Connection error: #{e.message}"
      { error: "Failed to connect to AI service: #{e.message}" }
    end
  end
end
