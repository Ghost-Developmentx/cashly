module Fin
  class BaseService
    include Rails.application.routes.url_helpers

    private

    def log_info(message)
      Rails.logger.info "[#{self.class.name}] #{message}"
    end

    def log_error(message)
      Rails.logger.error "[#{self.class.name}] #{message}"
    end

    def success_response(data = {}, message = nil)
      { success: true, **data }.tap do |response|
        response[:message] = message if message
      end
    end

    def error_response(error, message = nil)
      { success: false, error: error }.tap do |response|
        response[:message] = message if message
      end
    end
  end
end
