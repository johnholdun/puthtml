class UsersController < ApplicationController
  def show
    @user = Users.find(name: params[:user])
  end
end
