Rails.application.routes.draw do
  devise_for :users, controllers:
    { registrations: "users/registrations" }

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

  namespace :ai do
    get "insights", to: "insights#index"
    get "forecast", to: "insights#forecast"
    get "recommendation", to: "insights#recommendation"
  end

  resource :profile, only: [ :show, :edit, :update  ] do
    get "onboarding", on: :collection
    patch "complete_onboarding", on: :collection
    post "complete_tutorial", on: :collection
  end

  resources :plaid, only: [] do
    collection do
      post "create_link_token"
      post "exchange_public_token"
      post "sync"
    end
  end
end
