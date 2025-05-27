module Fin
  module Actions
    class CreateInvoiceAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "create_invoice"
      end

      def perform
        # Check if this is the new synchronous format (already has invoice_id)
        if tool_result["invoice_id"].present?
          # Invoice was already created by Python, just format the response
          {
            "type" => "invoice_created",
            "success" => true,
            "invoice_id" => tool_result["invoice_id"],
            "invoice" => tool_result["invoice"],
            "message" => tool_result["message"],
            "data" => tool_result
          }
        else
          # Fallback to the old format (shouldn't happen with new code)
          service = Fin::InvoiceService.new(user)
          result = service.create(tool_result["invoice"])

          if result[:success]
            {
              "type" => "invoice_created",
              "success" => true,
              "invoice_id" => result[:invoice_id],
              "invoice" => result[:invoice],
              "message" => result[:message],
              "data" => result
            }
          else
            error_response(result[:error])
          end
        end
      end
    end
  end
end
