module Billing
  class ListInvoices < BaseOperation
    attr_reader :user, :filters

    validates :user, presence: true

    def initialize(user:, filters: {})
      @user = user
      @filters = filters
    end

    def execute
      invoices = InvoiceQuery.new(user.invoices)
                             .with_filters(filters)
                             .execute

      success(
        invoices: present_invoices(invoices)
      )
    end

    private

    def present_invoices(invoices)
      invoices.map { |invoice| Billing::InvoicePresenter.new(invoice).as_json }
    end
  end
end
