class WelcomeController < ApplicationController
  before_filter :require_app_host

  def index
    headers['X-Frame-Options'] = 'DENY'

    @latest_documents = Post.order('created_at DESC').includes(:user).group(:user_id).limit(10)
    @greatest_documents = Post.order('views DESC').includes(:user).limit(10)
  end
end
