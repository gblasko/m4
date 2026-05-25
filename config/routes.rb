Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Auth (public)
  get  "/login",        to: "auth#login",        as: :login
  post "/auth/login",   to: "auth#create_token", as: :auth_create_token
  get  "/auth/check",   to: "auth#check",        as: :login_check
  get  "/auth/verify",  to: "auth#verify_link",  as: :verify_link
  post "/auth/verify",  to: "auth#verify_code",  as: :verify_code
  delete "/logout",     to: "auth#destroy",      as: :logout
  post   "/logout/all", to: "auth#sign_out_everywhere", as: :logout_everywhere

  # Dev-only quick login (gated server-side, controller checks Rails.env.development?)
  post "/dev/login", to: "auth#dev_login", as: :dev_login if Rails.env.development?

  # Customer routes
  root to: "boats#index", as: :root
  resources :boats, only: [:index, :show]
  resources :requests do
    member do
      post :cancel
      post :note
    end
  end
  get  "/account", to: "account#show",   as: :account
  patch "/account", to: "account#update"

  # Slot availability (JSON for customer time picker)
  get "/locations/:id/availability", to: "locations#availability", as: :location_availability

  # Staff dashboard
  get  "/dashboard", to: "dashboard#index", as: :dashboard
  get  "/dashboard/day",  to: "dashboard#day",  as: :dashboard_day
  get  "/dashboard/week", to: "dashboard#week", as: :dashboard_week
  patch "/requests/:id/status", to: "requests#status", as: :request_status
  patch "/requests/:id/assign", to: "requests#assign", as: :request_assign

  # Admin (manager only — except admin/requests which is staff-wide, gated in controller)
  namespace :admin do
    root to: "dashboard#index"
    resources :requests, only: [:new, :create]
    resources :customers do
      member { post :invite }
      resources :boats, only: [:index, :new, :create, :edit, :update, :destroy], controller: "customer_boats"
    end
    resources :locations do
      resources :slips, only: [:index, :new, :create, :edit, :update, :destroy]
    end
    resources :request_types do
      member { post :reorder }
    end
    resources :users
  end

  # Webhooks
  post "/webhooks/resend", to: "webhooks#resend"
  post "/webhooks/quo", to: "webhooks#quo"

  # ActionCable
  mount ActionCable.server => "/cable"
end
