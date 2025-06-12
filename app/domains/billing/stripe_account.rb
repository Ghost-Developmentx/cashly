module Billing
  class StripeAccount
    attr_reader :connect_account

    def initialize(connect_account)
      @connect_account = connect_account
    end

    def ready_for_payments?
      connect_account&.can_accept_payments? || false
    end

    def ready_for_payouts?
      connect_account&.can_receive_payouts? || false
    end

    def onboarding_complete?
      connect_account&.onboarding_complete? || false
    end

    def status_message
      return "Not connected" unless connect_account

      case connect_account.status
      when "active"
        "Active and ready to accept payments"
      when "pending"
        "Pending - complete onboarding to activate"
      when "rejected"
        "Account rejected - please contact support"
      else
        "Status: #{connect_account.status}"
      end
    end

    def requirements_message
      return nil unless connect_account&.requirements

      currently_due = connect_account.requirements["currently_due"] || []

      if currently_due.any?
        "Action required: #{currently_due.join(', ')}"
      else
        nil
      end
    end
  end
end