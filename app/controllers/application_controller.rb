class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  around_filter :catch_not_found

  private

  def catch_not_found
    yield
  rescue ActiveRecord::RecordNotFound
    redirect_to root_url, :flash => { error: "Resource not found." }
  end

  def current_user
    @current_user ||= User.first
  end
  helper_method :current_user
end
