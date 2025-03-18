Rails.application.routes.draw do
  # Root route
  root "dashboard#index"

  # Authentication routes
  devise_for :users, controllers: {
    registrations: "users/registrations",
    omniauth_callbacks: "users/omniauth_callbacks",
    confirmations: "users/confirmations"
  }

  # Dashboard routes
  get "dashboard", to: "dashboard#index"
  get "dashboard/hide_getting_started", to: "dashboard#hide_getting_started"

  # Dashboard React component data endpoints
  get "dashboard/cash_flow", to: "dashboard#cash_flow"
  get "dashboard/category_spending", to: "dashboard#category_spending"
  get "dashboard/budget_vs_actual", to: "dashboard#budget_vs_actual"

  # User profile
  resource :profile, only: [ :show, :edit, :update ] do
    collection do
      get "onboarding"
      patch "complete_onboarding"
      post "complete_tutorial"
    end
  end

  # Core financial management
  resources :accounts do
    resources :bank_statements do
      member do
        patch :reconcile
      end
    end
  end

  resources :transactions do
    collection do
      post :categorize_all
      post :category_feedback
    end

    member do
      patch :unreconcile
      patch :update_category
    end
  end

  resources :forecasts do
    member do
      get :compare
      get :scenarios
      post :create_scenario
    end
  end

  resources :budgets do
    collection do
      get :recommendations
      post :apply_all_recommendations
    end
  end

  resources :categories

  # Invoice management
  resources :invoices do
    member do
      post :send
      post :mark_as_paid
      post :set_recurring
      post :cancel_recurring
      get :preview
      post :send_reminder
      get :payment_status
    end

    collection do
      get :templates
      get :recurring
      post :preview_template
    end
  end

  # Import functionality
  resources :imports, only: [ :new, :create ] do
    collection do
      get "failed"
    end
  end

  # Integrations
  resources :integrations, only: [ :index, :new, :create, :destroy ] do
    collection do
      get :stripe
      post :connect_stripe
    end
  end

  # Stripe webhook
  post "/stripe/webhooks", to: "stripe_webhooks#create"

  # Plaid integration
  resources :plaid, only: [] do
    collection do
      post "create_link_token"
      post "exchange_public_token"
      post "sync"
    end
  end

  # Accounting features
  resources :category_account_mappings, only: [ :index, :create, :update, :destroy ]

  resources :ledger_accounts do
    member do
      patch :toggle_active
    end
  end

  get "chart_of_accounts", to: "ledger_accounts#index", as: "chart_of_accounts"

  resources :journal_entries do
    member do
      patch :post
      patch :reverse
    end
  end

  # Financial reports
  resources :reports, only: [ :index ] do
    collection do
      get :trial_balance
      get :income_statement
      get :balance_sheet
      get :cash_flow_statement
    end
  end

  # AI features
  namespace :ai do
    get "insights", to: "insights#index"
    get "forecast", to: "insights#forecast"
    get "recommendation", to: "insights#recommendation"
  end
end
