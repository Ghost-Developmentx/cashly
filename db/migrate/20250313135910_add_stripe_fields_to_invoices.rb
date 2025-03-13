class AddStripeFieldsToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :stripe_invoice_id, :string
    add_column :invoices, :stripe_payment_intent_id, :string
    add_column :invoices, :stripe_subscription_id, :string
    add_column :invoices, :stripe_customer_id, :string
    add_column :invoices, :payment_status, :string, default: 'awaiting_payment'
    add_column :invoices, :payment_method, :string
    add_column :invoices, :last_payment_attempt, :datetime
    add_column :invoices, :next_payment_date, :date
    add_column :invoices, :recurring, :boolean, default: false
    add_column :invoices, :recurring_interval, :string
    add_column :invoices, :recurring_period, :integer
    add_column :invoices, :template, :string, default: 'default'
    add_column :invoices, :currency, :string, default: 'usd'
    add_column :invoices, :client_email, :string
    add_column :invoices, :client_address, :text
    add_column :invoices, :notes, :text
    add_column :invoices, :terms, :text
    add_column :invoices, :custom_fields, :jsonb, default: {}

    add_index :invoices, :stripe_invoice_id
    add_index :invoices, :stripe_subscription_id
    add_index :invoices, :payment_status
  end
end
