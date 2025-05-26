module Fin
  module Actions
    class CreateInvoiceAction < BaseAction
      def validate!
        raise "Invalid action" unless tool_result["action"] == "create_invoice"
        raise "Invoice data required" unless tool_result["invoice"].present?
      end

      def perform
        invoice_data = tool_result["invoice"]

        invoice = user.invoices.build(
          client_name: invoice_data["client_name"],
          client_email: invoice_data["client_email"],
          amount: invoice_data["amount"].to_f,
          description: invoice_data["description"],
          issue_date: Date.current,
          due_date: calculate_due_date(invoice_data["due_date"]),
          status: "draft",
          currency: user.currency || "USD"
        )

        if invoice.save
          handle_stripe_integration(invoice)
        else
          error_response(invoice.errors.full_messages.join(", "))
        end
      end

      private

      def calculate_due_date(due_date_str)
        if due_date_str.present?
          Date.parse(due_date_str)
        else
          30.days.from_now.to_date
        end
      rescue ArgumentError
        30.days.from_now.to_date
      end

      def handle_stripe_integration(invoice)
        connect_account = user.stripe_connect_account

        if connect_account&.can_accept_payments?
          create_stripe_invoice(invoice)
        else
          success_response(
            "data" => {
              "invoice" => format_invoice(invoice),
              "invoice_id" => invoice.id
            },
            "message" => "Invoice ##{invoice.id} created successfully! It's currently a draft.",
            "invoice_id" => invoice.id
          )
        end
      end

      def create_stripe_invoice(invoice)
        service = StripeConnectService.new(user)
        stripe_result = service.create_invoice_with_fee({
                                                          amount: invoice.amount,
                                                          client_email: invoice.client_email,
                                                          client_name: invoice.client_name,
                                                          description: invoice.description,
                                                          currency: invoice.currency,
                                                          cashly_invoice_id: invoice.id,
                                                          days_until_due: (invoice.due_date - invoice.issue_date).to_i
                                                        })

        if stripe_result[:success]
          invoice.update!(stripe_invoice_id: stripe_result[:stripe_invoice].id)

          success_response(
            "data" => {
              "invoice" => format_invoice(invoice),
              "invoice_id" => invoice.id,
              "platform_fee" => stripe_result[:platform_fee]
            },
            "message" => "Invoice ##{invoice.id} created successfully! It's currently a draft.",
            "invoice_id" => invoice.id
          )
        else
          success_response(
            "data" => {
              "invoice" => format_invoice(invoice),
              "invoice_id" => invoice.id
            },
            "message" => "Invoice created but Stripe integration failed: #{stripe_result[:error]}",
            "invoice_id" => invoice.id
          )
        end
      end

      def format_invoice(invoice)
        {
          id: invoice.id,
          client_name: invoice.client_name,
          client_email: invoice.client_email,
          amount: invoice.amount.to_f,
          status: invoice.status,
          issue_date: invoice.issue_date.strftime("%Y-%m-%d"),
          due_date: invoice.due_date.strftime("%Y-%m-%d"),
          invoice_number: invoice.generate_invoice_number,
          description: invoice.description
        }
      end
    end
  end
end
