Rails.application.routes.draw do
  root 'welcome#index'

  resources :posts, except: :show

  get ':user_name' => 'users#show', as: :user
  get 'edit-put/*path' => 'posts#edit'
  delete '*path' => 'posts#destroy'
  get '*path' => 'posts#show'
end
