module Fin
  class DebugController < ApplicationController
    def action_registry
      render json: {
        registered_actions: Fin::ActionRegistry.actions.keys,
        action_count: Fin::ActionRegistry.actions.count,
        create_invoice_registered: Fin::ActionRegistry.actions.key?("create_invoice"),
        create_invoice_class: Fin::ActionRegistry.actions["create_invoice"]&.name
      }
    end
  end
end
