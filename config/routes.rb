Rails.application.routes.draw do
  devise_for :users
  root "dashboard#index"

  resources :accounts
  resources :transactions
  resources :invoices
  resources :budgets
  resources :categories

  get "dashboard", to: "dashboard#index"

  namespace :ai do
    get "insights", to: "insights#index"
    get "forecast", to: "insights#forecast"
    get "recommendation", to: "insights#recommendation"
  end
end
