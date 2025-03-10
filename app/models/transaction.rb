class Transaction < ApplicationRecord
  belongs_to :account
  belongs_to :category, optional: true

  delegate :user, to: :account
end
