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
        post :sync
      end
    end


    # Optional: legacy route to support /fin or redirect to dashboard
    get "/", to: "conversations#index"
  end

  namespace :api do
    namespace :internal do
      resources :invoices, only: [ :create ]
    end
  end

  # Plaid
  resources :plaid, only: [] do
    collection do
      post :create_link_token
      post :exchange_public_token
      post :sync
    end
  end
end
