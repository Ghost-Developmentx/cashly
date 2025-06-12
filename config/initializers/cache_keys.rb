module CacheKeys
  class << self
    def user_transactions(user_id, month = nil)
      month ||= Date.current.strftime("%Y-%m")
      "user/#{user_id}/transactions/#{month}"
    end

    def user_accounts(user_id)
      "user/#{user_id}/accounts"
    end

    def user_invoices(user_id, status = "all")
      "user/#{user_id}/invoices/#{status}"
    end

    def ai_context(user_id)
      "user/#{user_id}/ai_context"
    end

    def category_mappings
      "system/category_mappings"
    end
  end
end
