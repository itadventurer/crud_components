Rails.application.routes.draw do
  root 'home#index'   # the living-documentation landing page (a feature index)

  resources :books do
    collection do
      get :import
      delete :delete_selected
      get :export_selected
    end
    member { get :preview }
  end
  resources :publishers do
    resources :books, only: %i[index edit]
  end
  resources :authors do       # full CRUD — proves derived actions/forms on a zero-config model
    resources :books, only: :index   # nested index so an author's "+n more" books link resolves
  end
  resources :reviews, only: %i[index show edit update destroy]

  get 'dashboard', to: 'dashboard#show'
  get 'pagination', to: 'pagination#index'   # how to paginate a big table (bring your own pager)
  get 'groups', to: 'groups#index'           # collapsible groups via group_by:
  get 'custom_fields', to: 'custom_fields#index'  # dynamic columns from a custom-property store
  get 'columns', to: 'columns#index'              # per-user column picker (?cols=)
  get 'column_headers', to: 'column_headers#index'  # dynamic-column custom headers + header actions
  post 'column_headers/tag', to: 'column_headers#tag', as: :tag_column_headers  # a :selection header action target
  get 'renderers', to: 'renderers#index'   # soft-dependency renderers (markdown/json) + crud_actions
  get 'documents', to: 'documents#index'   # STI + asciidoc + polymorphic comments
  get 'live', to: 'live#index'
  post 'live/poke', to: 'live#poke'
  post 'toggle_admin', to: 'application#toggle_admin'
end
