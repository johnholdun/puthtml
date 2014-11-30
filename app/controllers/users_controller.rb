class UsersController < ApplicationController
  before_filter :require_app_host, only: :show

  def show
    @user = User.find_by_name params[:user_name]
    @latest_documents = @user.posts.order('created_at DESC').limit(10)
  end
end
