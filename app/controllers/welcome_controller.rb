class WelcomeController < ApplicationController
  def index
    @documents = Post.order('RANDOM()').limit(10)
  end
end
