class UsersController < ApplicationController
  before_filter :require_app_host, only: :show

  def show
    @user = User.find_by_name params[:user_name]
    @latest_documents = @user.posts.order('created_at DESC').limit(10)
  end

  def generate_api_key
    if current_user
      current_user.generate_api_key true
      current_user.save
    end

    flash.notice = 'Your API key is brand new. So fresh.'

    redirect_to root_path
  end
end
