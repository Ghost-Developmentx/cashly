namespace :maintenance do
  desc "Clean up old conversations"
  task cleanup_old_conversations: :environment do
    puts "Cleaning up conversations older than 30 days..."

    count = FinConversation
              .where("created_at < ?", 30.days.ago)
              .where(active: false)
              .destroy_all
              .count

    puts "Deleted #{count} old conversations"
  end

  desc "Sync all Plaid accounts"
  task sync_all_plaid_accounts: :environment do
    puts "Syncing all Plaid accounts..."

    User.joins(:plaid_tokens).distinct.find_each do |user|
      begin
        result = Banking::SyncBankAccounts.call(user: user)
        if result.success?
          puts "✓ Synced accounts for user #{user.id}"
        else
          puts "✗ Failed to sync for user #{user.id}: #{result.error}"
        end
      rescue => e
        puts "✗ Error syncing user #{user.id}: #{e.message}"
      end
    end
  end

  desc "Categorize uncategorized transactions"
  task categorize_transactions: :environment do
    puts "Categorizing uncategorized transactions..."

    Transaction.where(category_id: nil).find_in_batches(batch_size: 100) do |batch|
      batch.each do |transaction|
        CategorizeTransactionsJob.perform_later(transaction.id)
      end
      puts "Queued #{batch.size} transactions for categorization"
    end
  end
end
