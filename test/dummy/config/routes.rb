Rails.application.routes.draw do
  root 'books#index'

  resources :books do
    member { get :preview }
  end
  resources :publishers do
    resources :books, only: %i[index edit]
  end
  resources :authors, only: %i[index]
  resources :reviews, only: %i[index show edit destroy]

  get 'dashboard', to: 'dashboard#show'
  post 'toggle_admin', to: 'application#toggle_admin'
end
