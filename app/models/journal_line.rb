class JournalLine < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :ledger_account
end
