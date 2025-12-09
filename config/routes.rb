Rails.application.routes.draw do
  mount Blazer::Engine, at: "/analytics"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "checks#index"

  get "backdoor" => "checks#backdoor"

  resources :checks do
    member do
      post :toggle_zero_items
      patch :update_currency
    end
    resources :participants, only: [:create, :show, :edit, :update, :destroy]
    resources :line_items, only: [:create, :show, :edit, :update, :destroy]
    resources :global_discounts, only: [:create, :show, :edit, :update, :destroy]
    resources :global_fees, only: [:create, :show, :edit, :update, :destroy] do
      collection do
        post :set_tip
      end
    end
  end

  resources :line_items, only: [] do
    member do
      post :toggle_participant
      post :toggle_all_participants
    end
    resources :addons, only: [:show, :edit, :update, :destroy]
  end
end
