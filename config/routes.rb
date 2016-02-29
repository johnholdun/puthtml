Rails.application.routes.draw do
  root 'welcome#index'

  post '/' => 'posts#create'
  resources :posts, except: :show

  get '/auth/twitter/callback', to: 'sessions#create', as: 'callback'
  get '/auth/failure', to: 'sessions#error', as: 'failure'
  get '/auth/backdoor/:username', to: 'sessions#backdoor' unless Rails.env.production?
  delete '/sign-out', to: 'sessions#destroy', as: 'signout'

  post '/settings/api-key' => 'users#generate_api_key'

  get ':user_name' => 'users#show', as: :user
  get 'edit-put/:user_name/*path' => 'posts#edit'
  delete ':user_name/*path' => 'posts#destroy', constraints: lambda { |req| req.fullpath !~ %r(\A/auth/) }
  get ':user_name/*path' => 'posts#show', constraints: lambda { |req| req.fullpath !~ %r(\A/auth/) }
end
