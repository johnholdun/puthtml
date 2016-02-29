require 'spec_helper'

RSpec.describe PostsController, type: :controller do
  let(:username) { Faker::Internet.user_name nil, %w(_) }
  let(:path) { Faker::Internet.slug }
  let!(:user) { User.create name: username, uid: SecureRandom.random_number(10_000).to_s }

  describe 'GET #show' do
    it 'increases view count' do
      post = user.posts.create path: "#{ path }.html", contents: '<h1>this is viewed</h1>'
      5.times { get :show, user_name: username, path: path }
      expect(post.reload.views).to eq(5)
    end

    it 'sets content type' do
      post = user.posts.create path: "#{ path }.html", contents: '<h1>this is viewed</h1>'
      get :show, user_name: username, path: path
      expect(response.content_type).to eq('text/html')
    end
  end

  describe 'POST #create' do
    context 'for the current user' do
      it 'saves a post' do
        allow_any_instance_of(described_class).to receive(:current_user).and_return(user)
        post :create, post: { path: "#{ path }.html", contents: '<h1>this is a journey</h1>' }
        expect(response.content_type).to eq('text/html')
      end
    end

    context 'for an API key' do
      it 'saves a post' do
        post :create, api_key: user.api_key, post: { path: "#{ path }.html", contents: '<h1>this is a journey</h1>' }
        expect(response.content_type).to eq('text/html')
      end
    end

    it 'updates an existing post instead of creating a duplicate' do
      allow_any_instance_of(described_class).to receive(:current_user).and_return(user)
      existing_post = user.posts.create path: "#{ path }.html", contents: '<h1>this is an original</h1>'
      post :create, post: { path: existing_post.path, contents: '<h1>this is a new</h1>' }
      expect(response.content_type).to eq('text/html')
    end
  end
end
