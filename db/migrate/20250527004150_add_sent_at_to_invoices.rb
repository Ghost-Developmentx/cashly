class AddSentAtToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :sent_at, :datetime
  end
end
