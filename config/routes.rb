Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Root route pointing to the central dashboard
  root "dashboard#show"

  resource :dashboard, only: [ :show ], controller: :dashboard
  resources :conversations, only: [ :index, :show, :create, :update, :destroy ] do
    resources :messages, only: [ :create ], module: :conversations do
      collection do
        post :regenerate
      end
    end
  end
  resource :email_generator, only: [ :show, :create ], controller: :email_generator
  resource :summarizer, only: [ :show ], controller: :summarizer
  resource :settings, only: [ :show ], controller: :settings
end
