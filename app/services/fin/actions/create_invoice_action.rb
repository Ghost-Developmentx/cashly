module Fin
  module Actions
    class CreateInvoiceAction < BaseAction
      def validate!
        true
      end

      def perform
        if tool_result["invoice_id"].present?
          {
            "type" => "invoice_create_success", # Updated action type
            "success" => true,
            "invoice_id" => tool_result["invoice_id"],
            "invoice" => tool_result["invoice"],
            "data" => tool_result,
            "silent" => false
          }
        else
          {
            "type" => "invoice_create_success", # Updated action type
            "success" => true,
            "silent" => true
          }
        end
      end
    end
  end
end