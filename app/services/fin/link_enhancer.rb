module Fin
  class LinkEnhancer
    LINK_MAPPINGS = {
      "get_transactions" => [ { text: "View All Transactions", url: "/transactions" } ],
      "show_forecast" => [ { text: "View Full Forecast", url: "/forecasts" } ],
      "show_trends" => [ { text: "View All Insights", url: "/ai/insights" } ],
      "show_budget" => [ { text: "Manage Budgets", url: "/budgets" } ],
      "show_categories" => [ { text: "View All Transactions", url: "/transactions" } ],
      "show_anomalies" => [ { text: "View All Transactions", url: "/transactions" } ],
      "transaction_created" => [ { text: "View All Transactions", url: "/transactions" } ],
      "transaction_updated" => [ { text: "View All Transactions", url: "/transactions" } ],
      "transaction_deleted" => [ { text: "View All Transactions", url: "/transactions" } ],
      "stripe_connect_error" => [ { text: "Stripe Connect Help", url: "/help/stripe-connect" } ]
    }.freeze

    def enhance(action)
      return action unless action.is_a?(Hash)

      # Add links based on the action type
      if LINK_MAPPINGS[action["type"]]
        action["links"] ||= []
        action["links"].concat(LINK_MAPPINGS[action["type"]])
      end

      # Special handling for certain action types
      case action["type"]
      when "create_stripe_connect_dashboard_link"
        action["type"] = "open_stripe_dashboard"
      end

      action
    end
  end
end
