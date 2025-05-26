class AddDescriptionToInvoices < ActiveRecord::Migration[7.0]
  def change
    add_column :invoices, :description, :text
    add_column :invoices, :notes, :text, if_not_exists: true
    add_column :invoices, :currency, :string, default: 'USD', if_not_exists: true
    add_column :invoices, :template, :string, default: 'default', if_not_exists: true

    # Add other missing columns that are referenced in the model
    add_column :invoices, :payment_status, :string, default: 'awaiting_payment', if_not_exists: true
    add_column :invoices, :recurring, :boolean, default: false, if_not_exists: true
    add_column :invoices, :stripe_invoice_id, :string, if_not_exists: true
    add_column :invoices, :stripe_subscription_id, :string, if_not_exists: true
    add_column :invoices, :custom_fields, :json, if_not_exists: true

    # Add indexes for performance
    add_index :invoices, :stripe_invoice_id, if_not_exists: true
    add_index :invoices, :status, if_not_exists: true
    add_index :invoices, :due_date, if_not_exists: true
  end
end
