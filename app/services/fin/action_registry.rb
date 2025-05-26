module Fin
  class ActionRegistry
    class << self
      def actions
        @actions ||= {}
      end

      def register(tool_name, action_class)
        actions[tool_name.to_s] = action_class
        Rails.logger.info "[ActionRegistry] Registered: #{tool_name} -> #{action_class}"
      end

      def execute(tool_name, user, tool_result, params = {})
        action_class = actions[tool_name.to_s]

        unless action_class
          Rails.logger.warn "[ActionRegistry] No action registered for tool: #{tool_name}"
          return nil
        end

        action_class.new(user, tool_result, params).execute
      rescue StandardError => e
        Rails.logger.error "[ActionRegistry] Error executing #{tool_name}: #{e.message}"
        {
          "type" => "#{tool_name}_error",
          "success" => false,
          "error" => e.message
        }
      end
    end
  end
end
