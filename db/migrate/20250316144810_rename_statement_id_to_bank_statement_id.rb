class RenameStatementIdToBankStatementId < ActiveRecord::Migration[8.0]
  def change
    # First remove the index if it exists (using a more robust approach)
    begin
      remove_index :transactions, :statement_id
    rescue => e
      puts "Index doesn't exist: #{e.message}"
      # Continue with migration even if index doesn't exist
    end

    # Then rename the column
    rename_column :transactions, :statement_id, :bank_statement_id

    # Add the new index
    add_index :transactions, :bank_statement_id
  end
end
