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

      # Initialize an action array
      ai_response["actions"] ||= []

      # Process tool results
      if ai_response["tool_results"].present?
        processed_tools = Set.new

        ai_response["tool_results"].each do |tool_result|
          tool_key = "#{tool_result['tool']}_#{tool_result.object_id}"
          next if processed_tools.include?(tool_key)

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
  end
end
