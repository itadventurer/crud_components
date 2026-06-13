Rails.application.routes.draw do
  root 'books#index'

  resources :books do
    collection { get :import }
    member { get :preview }
  end
  resources :publishers do
    resources :books, only: %i[index edit]
  end
  resources :authors          # full CRUD — proves derived actions/forms on a zero-config model
  resources :reviews, only: %i[index show edit destroy]

  get 'dashboard', to: 'dashboard#show'
  get 'live', to: 'live#index'
  post 'live/poke', to: 'live#poke'
  post 'toggle_admin', to: 'application#toggle_admin'
end
