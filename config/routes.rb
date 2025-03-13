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

  resources :accounts
  resources :transactions
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
