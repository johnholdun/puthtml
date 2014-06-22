class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  around_filter :catch_not_found

  private

  def catch_not_found
    yield
  rescue ActiveRecord::RecordNotFound
    redirect_to root_url, flash: { error: 'Resource not found.' }
  end

  def current_user
    @current_user ||= User.first
  end
  helper_method :current_user

  def require_content_host
    if request.host != CONTENT_HOST
      redirect_to "#{ request.scheme }://#{ CONTENT_HOST }#{ request.path }", status: 301
      return
    end
  end
  helper_method :require_content_host


  def require_app_host
    if request.host != APP_HOST
      redirect_to "#{ request.scheme }://#{ APP_HOST }#{ request.path }"
      return
    end
  end
  helper_method :require_content_host
end
