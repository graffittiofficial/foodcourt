Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[new create]
  resources :passwords, param: :token

  namespace :admin do
    root "dashboard#show"
    resources :restaurants, only: %i[index new create edit update] do
      post :connect, on: :member
      get :connect, on: :member
    end
    resources :orders, only: %i[index update]
    resources :drivers, only: %i[index new create]
  end

  namespace :driver do
    root "deliveries#index"
    resources :deliveries, only: %i[index] do
      patch :advance, on: :member
    end
  end

  namespace :staff do
    root "dashboard#show", as: :dashboard
    resources :orders, only: %i[index show new create] do
      member do
        patch :advance
        patch :cancel
      end
    end
    resources :menu_items, only: %i[index new create edit update] do
      patch :archive, on: :member
    end
  end

  resources :restaurants, only: %i[index show]
  get "cart", to: "cart#show", as: :cart
  post "cart/items", to: "cart#add_item", as: :cart_items
  patch "cart/items/:menu_item_id", to: "cart#update_item", as: :cart_item
  delete "cart/items/:menu_item_id", to: "cart#remove_item"
  get "checkouts/new", to: "checkouts#new", as: :new_checkout
  post "checkouts", to: "checkouts#create", as: :checkouts
  get "checkouts/success", to: "checkouts#success", as: :checkout_success
  resources :orders, only: %i[index show]
  post "webhooks/stripe", to: "stripe_webhooks#create", as: :stripe_webhook

  root "home#show"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  match "/404", to: "errors#not_found", via: :all
  match "/422", to: "errors#unprocessable_entity", via: :all
  match "/500", to: "errors#internal_server_error", via: :all

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
