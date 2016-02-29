class PostsController < ApplicationController
  before_filter :require_app_host, only: %w[edit destroy]
  before_filter :require_content_host, only: :show

  protect_from_forgery unless: Proc.new{ |c| c.params.is_a?(Hash) and c.params[:action] == 'create' and c.params.key? :api_key }

  def show
    # @todo Consider avoiding a DB request here in favor of Post.file_store.get params[:path]

    path = [params[:path]].flatten.join('/')
    path += ".#{ params[:format] }" if params[:format].present?

    post = Post.find_by_user_name_and_path params[:user_name], path

    raise ActiveRecord::RecordNotFound unless post.present?

    post.increment! :views

    render text: post.contents, content_type: post.content_type
  end

  def create
    user = if params.key? :api_key
      params[:post] ||= {}

      %w[file path].each do |attr|
        params[:post][attr] ||= params[attr] if params.key? attr
      end

      User.find_by_api_key params[:api_key]
    else
      current_user
    end

    post = Post.find_by_user_name_and_path(user.name, post_params[:path]) || user.posts.new

    post.attributes = post_params

    if post.save
      redirect_to post_path(post)
    else
      render :edit, locals: { post: post, copy: false }
    end
  end

  def edit
    post = Post.find_by_user_name_and_path params[:user_name], [params[:path]].join('.')

    raise ActiveRecord::RecordNotFound unless post

    render :edit, locals: { post: post, copy: (post.user != current_user) }
  end

  def update
    post = current_user.posts.find(params[:id])

    if post.update_attributes(post_params)
      redirect_to post_path(post)
    else
      render :edit, locals: { post: post, copy: false }
    end
  end

  def destroy
    post = Post.find_by_user_name_and_path params[:user_name], [params[:path]].join('.')

    if post.user == current_user
      post.destroy
      flash.notice = 'Post deleted.'
    else
      flash.error = 'You are not allowed to do that!'
    end

    redirect_to root_path
  end

  private

  def post_params
    params.require(:post).permit(:file, :contents, :path, :apikey)
  end
end
