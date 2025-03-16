Rails.application.routes.draw do
  devise_for :users, controllers:
    { registrations: "users/registrations",
      omniauth_callbacks: "users/omniauth_callbacks",
      confirmations: "users/confirmations" }

  root "dashboard#index"

  resource :profile, only: [ :show, :edit, :update  ] do
    get "onboarding", on: :collection
    patch "complete_onboarding", on: :collection
    post "complete_tutorial", on: :collection
  end

  resources :accounts do
    resources :bank_statements do
      member do
        patch :reconcile
      end
    end
  end

  resources :transactions do
    member do
      patch :unreconcile
    end
  end

  resources :budgets
  resources :categories

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

  resources :integrations, only: [ :index, :new, :create, :destroy ] do
    collection do
      get :stripe
      post :connect_stripe
    end
  end

  resources :imports, only: [ :new, :create ] do
    collection do
      get "failed"
    end
  end
  get "dashboard", to: "dashboard#index"
  get "dashboard/hide_getting_started", to: "dashboard#hide_getting_started"
  post "/stripe/webhooks", to: "stripe_webhooks#create"

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

  resources :reports, only: [ :index ] do
    collection do
      get :trial_balance
      get :income_statement
      get :balance_sheet
      get :cash_flow_statement
    end
  end

  namespace :ai do
    get "insights", to: "insights#index"
    get "forecast", to: "insights#forecast"
    get "recommendation", to: "insights#recommendation"
  end


  resources :plaid, only: [] do
    collection do
      post "create_link_token"
      post "exchange_public_token"
      post "sync"
    end
  end
end
