module Fin
  class ResponseProcessor
    def initialize(user)
      @user = user
      @link_enhancer = LinkEnhancer.new
    end

    def process(ai_response)
      return ai_response if ai_response[:error]

      Rails.logger.info "[ResponseProcessor] Processing AI response"
      Rails.logger.info "[ResponseProcessor] Tool results: #{ai_response['tool_results']&.length || 0}"

      ai_response["actions"] ||= []

      if ai_response["tool_results"].present?
        processed_tools = Set.new

        ai_response["tool_results"].each do |tool_result|
          tool_key = generate_tool_key(tool_result)

          if processed_tools.include?(tool_key)
            Rails.logger.warn "[ResponseProcessor] Skipping duplicate tool: #{tool_key}"
            next
          end

          action = Fin::ActionRegistry.execute(
            tool_result["tool"],
            @user,
            tool_result["result"],
            tool_result["parameters"]
          )

          if action
            ai_response["actions"] << @link_enhancer.enhance(action)
          end

          processed_tools.add(tool_key)
        end
      end

      Rails.logger.info "[ResponseProcessor] Final actions: #{ai_response['actions'].length}"
      ai_response
    end

    private

    def generate_tool_key(tool_result)
      tool_name = tool_result["tool"]
      params = tool_result["parameters"] || {}
      sorted_params = params.sort.to_h
      "#{tool_name}_#{sorted_params.to_json}"
    end
  end
end
