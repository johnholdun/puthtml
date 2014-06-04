class WelcomeController < ApplicationController
  def index
    @latest_documents = Post.order('created_at DESC').limit(10)
    @greatest_documents = Post.order('views DESC').limit(10)
  end
end
