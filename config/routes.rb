Rails.application.routes.draw do
  # Authenticated Clerk user endpoint
  get "/me", to: "me#show"
  patch "/me", to: "me#update"

  # Fin Assistant (AI CFO) routes
  namespace :fin do
    resources :accounts, only: [] do
      collection do
        post :create_link_token
        post :connect_account
        delete :disconnect_account
        post :sync_accounts
        get :account_status
      end
    end

    resources :conversations, only: [ :index, :show ] do
      collection do
        post :query
        post :clear
        post :feedback
        get :history
      end
    end

    resources :transactions, only: [ :index, :show, :create, :update, :destroy ] do
      collection do
        post :categorize_bulk
      end
    end


    resources :stripe, only: [] do
      collection do
        post :connect
        delete :disconnect
        get :status
      end
    end

    resources :stripe_connect, only: [] do
      collection do
        get :status
        post :setup
        post :restart_setup
        post :create_onboarding_link
        post :dashboard_link
        get :earnings
        delete :disconnect
        post :webhook
        get :onboarding_refresh
        get :onboarding_success
      end
    end

    resources :invoices, only: [ :create, :update ] do
      member do
        post :send_invoice
        post :send_reminder
        patch :mark_paid
      end
    end


    # Optional: legacy route to support /fin or redirect to dashboard
    get "/", to: "conversations#index"
  end

  # Stripe Connect onboarding flow - these need to be outside namespace for Stripe redirects
  get "dashboard/summary", to: "dashboard#summary"
  get "dashboard/cash_flow", to: "dashboard#cash_flow"


  # Core financial management
  resources :accounts do
    resources :bank_statements, only: [ :index, :show, :create, :update, :destroy ] do
      patch :reconcile, on: :member
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

  # Invoicing
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

  # Integrations
  resources :integrations, only: [ :index, :new, :create, :destroy ] do
    collection do
      get :stripe
      post :connect_stripe
    end
  end

  post "/stripe/webhooks", to: "stripe_webhooks#create"

  # Plaid
  resources :plaid, only: [] do
    collection do
      post :create_link_token
      post :exchange_public_token
      post :sync
    end
  end

  # Accounting
  resources :category_account_mappings, only: [ :index, :create, :update, :destroy ]

  resources :ledger_accounts do
    patch :toggle_active, on: :member
  end
  get "/chart_of_accounts", to: "ledger_accounts#index"

  resources :journal_entries do
    member do
      patch :post
      patch :reverse
    end
  end

  # Financial reports
  namespace :reports do
    get :trial_balance
    get :income_statement
    get :balance_sheet
    get :cash_flow_statement
  end

  # AI Insights
  namespace :ai do
    get :insights
    get :forecast
    get :recommendation
  end
end
