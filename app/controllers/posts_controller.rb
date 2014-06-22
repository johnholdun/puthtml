class PostsController < ApplicationController
  before_filter :require_app_host, only: %w[edit destroy]
  before_filter :require_content_host, only: :show
  before_filter :extract_file_info, only: [:create, :update]

  def show
    path = "#{ params[:path] }.#{ params[:format] || 'html' }"
    @post = Post.find_by_path path
    raise ActiveRecord::RecordNotFound unless @post

    render text: @post.contents, content_type: @post.content_type
  end

  def create
    @post = current_user.posts.new post_params

    if @post.save then
      redirect_to @post.path
    else
      render :edit
    end
  end

  def edit
    path = "#{ params[:path] }.#{ params[:format] || 'html' }"
    @post = Post.find_by_path path
    raise ActiveRecord::RecordNotFound unless @post

    @copy = !(@post.user == current_user)
    render :'edit.html'
  end


  def update
    @post = current_user.posts.find(params[:id])

    if @post.update_attributes(post_params) then
      redirect_to @post.path
    else
      render :edit
    end
  end

  def destroy
    @post = current_user.posts.find(params[:id])

    @post.destroy
    flash.notice 'Post deleted.'

    redirect_to current_user
  end

  private

  def post_params
    params.require(:post).permit(:file, :contents, :path, :apikey)
  end

  def extract_file_info
    if params[:file].is_a? Hash
      tmpfile = params[:file][:tempfile]
      # if this file is huge, don't read the whole thing--
      # just enough to trigger the "too large" error
      # (i'm not sure this actually gains us anything)
      params[:contents] = open(tmpfile).read(Post::MAX_FILE_SIZE + 1)
      params[:path] = params[:path].to_s.strip.present? ? params[:path].strip : params[:file][:filename]
    end
  end
end
