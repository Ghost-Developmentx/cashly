module Fin
  module Actions
    class BaseAction
      attr_reader :user, :tool_result, :params

      def self.tool_name
        name.demodulize.gsub("Action", "").underscore
      end

      def initialize(user, tool_result, params = {})
        @user = user
        @tool_result = tool_result
        @params = params
      end

      def execute
        Rails.logger.info "[#{self.class.name}] Executing with params: #{params}"
        validate!
        perform
      rescue StandardError => e
        Rails.logger.error "[#{self.class.name}] Error: #{e.message}"
        error_response(e.message)
      end

      protected

      def validate!
        # Override in subclasses
      end

      def perform
        raise NotImplementedError
      end

      def success_response(data = {})
        {
          "type" => self.class.tool_name,
          "success" => true,
          **data
        }
      end

      def error_response(error)
        {
          "type" => "#{self.class.tool_name}_error",
          "success" => false,
          "error" => error
        }
      end

      def log_info(message)
        Rails.logger.info "[#{self.class.name}] #{message}"
      end
    end
  end
end
