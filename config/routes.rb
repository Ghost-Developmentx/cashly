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
  resources :invoices
  resources :budgets
  resources :categories

  resources :imports, only: [ :new, :create ] do
    collection do
      get "failed"
    end
  end
  get "dashboard", to: "dashboard#index"
  get "dashboard/hide_getting_started", to: "dashboard#hide_getting_started"

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
