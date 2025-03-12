Rails.application.routes.draw do
  devise_for :users
  root "dashboard#index"

  resources :accounts
  resources :transactions
  resources :invoices
  resources :budgets
  resources :categories

  resources :imports, only: [ :new, :create ] do
    collection do
      get "failed"
    end
  end
  get "dashboard", to: "dashboard#index"
  get "plaid/debug", to: "plaid#debug"
  get "plaid/force_sync", to: "plaid#force_sync"

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
