class PostsController < ApplicationController
  before_filter :require_app_host, only: %w[edit destroy]
  before_filter :require_content_host, only: :show
  before_filter :set_path_param

  protect_from_forgery unless: Proc.new{ |c| c.params.is_a?(Hash) and c.params[:action] == 'create' and c.params.key? :api_key }

  def show
    @post = Post.find_by_path params[:path]
    raise ActiveRecord::RecordNotFound unless @post

    render text: @post.contents, content_type: @post.content_type
  end

  def create
    if params.key? :api_key
      params[:post] ||= {}

      %w[file path].each do |attr|
        params[:post][attr] ||= params[attr] if params.key? attr
      end

      user = User.find_by_api_key params[:api_key]
    else
      user = current_user
    end

    @post = user.posts.new post_params

    if @post.save
      redirect_to "/#{ @post.path false }"
    else
      render :edit
    end
  end

  def edit
    path = params[:path].sub %r[^/edit-put/], ''

    @post = Post.find_by_path path
    raise ActiveRecord::RecordNotFound unless @post

    @copy = !(@post.user == current_user)
    render :'edit.html'
  end


  def update
    @post = current_user.posts.find(params[:id])

    if @post.update_attributes(post_params)
      redirect_to @post.path
    else
      render :edit
    end
  end

  def destroy
    @post = current_user.posts.find_by_path params[:path]

    @post.destroy
    flash.notice = 'Post deleted.'

    redirect_to root_path
  end

  private

  def post_params
    params.require(:post).permit(:file, :contents, :path, :apikey)
  end

  def set_path_param
    path = params[:path] || request.path
    return true unless path.present?
    path += '.html' unless path =~ /\.[^\/]+\/?$/
    params[:path] = path
  end
end
