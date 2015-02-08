class SessionsController < ApplicationController
  before_filter :require_app_host

  def create
    unless current_user
      auth = request.env['omniauth.auth']
      user = User.find_by_uid(auth['uid']) ||
             User.create_with_omniauth(auth)
      cookies.permanent.signed[:user_id] = user.uid
    end
    redirect_to root_path, notice: 'All signed in, champ.'
  end

  def show
    if current_user
      @twitter_user = client.user(include_entities: true)
    else
      redirect_to failure_path
    end
  end

  def backdoor
    unless Rails.env.production?
      user = User.find_by_name params[:username]
      if user.present?
        cookies.permanent.signed[:user_id] = user.uid
        flash.notice = 'Our little secret.'
      end
    end

    redirect_to root_path
  end

  def error
    flash[:error] = 'Sign in with Twitter failed'
    redirect_to root_path
  end

  def destroy
    cookies.delete :user_id
    redirect_to root_path, notice: 'Signed out'
  end
end
