module FinancialAI
  class AiResponse
    attr_reader :raw_response, :message, :tool_results, :actions

    def initialize(raw_response)
      @raw_response = raw_response
      parse_response
    end

    def success?
      !error?
    end

    def error?
      raw_response.is_a?(Hash) && raw_response[:error].present?
    end

    def error_message
      raw_response[:error] if error?
    end

    def to_h
      if error?
        { error: error_message }
      else
        {
          response_text: message,
          tool_results: tool_results,
          actions: actions
        }
      end
    end

    private

    def parse_response
      return if error?

      @message = extract_message
      @tool_results = raw_response["tool_results"] || []
      @actions = raw_response["actions"] || []
    end

    def extract_message
      raw_response["response_text"] ||
        raw_response["message"] ||
        raw_response["response"] ||
        "I'm not sure how to respond to that."
    end
  end
end
