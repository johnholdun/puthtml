Rails.application.routes.draw do
  root 'welcome#index'

  post '/' => 'posts#create'
  resources :posts, except: :show

  get '/auth/twitter/callback', to: 'sessions#create', as: 'callback'
  get '/auth/failure', to: 'sessions#error', as: 'failure'
  delete '/signout', to: 'sessions#destroy', as: 'signout'

  get ':user_name' => 'users#show', as: :user
  get 'edit-put/*path' => 'posts#edit'
  delete '*path' => 'posts#destroy'
  get '*path' => 'posts#show'
end
