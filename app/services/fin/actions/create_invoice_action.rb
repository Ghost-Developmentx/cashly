module Fin
  module Actions
    class CreateInvoiceAction < BaseAction
      def validate!
        true
      end

      def perform
        # Use the new operation
        result = Billing::CreateInvoice.call(
          user: user,
          params: tool_result["invoice"] || {}
        )

        if result.success?
          {
            "type" => "invoice_create_success",
            "success" => true,
            "invoice_id" => result.data[:invoice_id],
            "invoice" => result.data[:invoice],
            "data" => result.data,
            "message" => result.data[:message],
            "silent" => false
          }
        else
          {
            "type" => "invoice_create_error",
            "success" => false,
            "error" => result.error,
            "message" => result.error
          }
        end
      end
    end
  end
end
