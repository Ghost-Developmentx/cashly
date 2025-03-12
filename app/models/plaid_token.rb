class PlaidToken < ApplicationRecord
  belongs_to :user

  attr_encrypted :access_token, key: ENV["ENCRYPTION_KEY"]

  # validates :access_token, presence: true
  validates :item_id, presence: true, uniqueness: true
end
