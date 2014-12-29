Rails.application.routes.draw do
  root 'welcome#index'

  post '/' => 'posts#create'
  resources :posts, except: :show

  get '/auth/twitter/callback', to: 'sessions#create', as: 'callback'
  get '/auth/failure', to: 'sessions#error', as: 'failure'
  delete '/sign-out', to: 'sessions#destroy', as: 'signout'

  post '/settings/api-key' => 'users#generate_api_key'

  get ':user_name' => 'users#show', as: :user
  get 'edit-put/*path' => 'posts#edit'
  delete '*path' => 'posts#destroy'
  get '*path' => 'posts#show', constraints: { path: /(?!.*?auth\/).*/ }
end
