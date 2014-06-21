require 'rubygems'
require 'bundler/setup'
require 'omniauth'
require 'omniauth-twitter'
require 'dm-core'
require 'dm-migrations'
require 'rack-flash'
require 'active_support/all'

Bundler.require

require 'sinatra/asset_pipeline'

require_relative 'models/init'

Dir.glob('lib/*.rb').each{ |path| require_relative path }

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/database.db")
DataMapper.finalize
DataMapper.auto_upgrade!

class PutHTML < Sinatra::Base
  use OmniAuth::Strategies::Twitter, ENV['TWITTER_CONSUMER_KEY'], ENV['TWITTER_CONSUMER_SECRET']

  configure do
    set :session_secret, ENV['COOKIE_SECRET']
    enable :sessions
  end

  set :assets_precompile, %w[*.css *.js]
  register Sinatra::AssetPipeline

  helpers do
    def current_user
      @current_user ||= User.get(session[:user_id]) if session[:user_id]
    end
  end

  AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID']
  AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY']
  Bucket = AWS::S3.new.buckets[ENV['AWS_BUCKET_NAME']] rescue nil

  MAX_FILE_SIZE = 1_048_576

  ACCEPTABLE_MIME_TYPES = %w[
    text/html
    application/json
    text/css
    application/javascript
    application/yaml
  ]

  EXTNAMES_BY_MIME_TYPE = {
    'text/html' => '.html',
    'application/json' => '.json',
    'text/css' => '.css',
    'application/javascript' => '.js',
    'application/yaml' => '.yml',
  }

  EDITOR_MODES = {
    '.json' => 'json',
    '.js' => 'javascript',
    '.html' => 'html',
    '.yml' => 'yaml',
    '.css' => 'css'
  }

  use Rack::Flash

  REDIS_URL = ENV['REDISCLOUD_URL']
  REDIS = if REDIS_URL
    uri = URI.parse(REDIS_URL)
    Redis.new host: uri.host, port: uri.port, password: uri.password
  else
    Redis.new
  end

  # if (Bucket.present? rescue false)
  #   documents = Bucket.objects.map do |obj|
  #     next if obj.key =~ /^_legacy\// # legacy duh
  #     Document.new path: obj.key, updated_at: obj.last_modified
  #   end

  #   documents.compact! # just for legacy

  #   # start fresh
  #   REDIS.del(['documents'] + REDIS.keys('documents.*'))
  #   REDIS.zadd 'documents', documents.map{ |doc| [doc.updated_at.to_i, doc.path] }.flatten
  #   documents.group_by(&:user_id).each do |user_id, docs|
  #     next if docs.first.user.nil?
  #     REDIS.zadd "documents.#{ docs.first.user.name }", docs.map{ |doc| [doc.updated_at.to_i, doc.path] }.flatten
  #   end
  # end

  before do
    #force app host if not content host
    if request.host != PUTHTML_APP_HOST and request.host != PUTHTML_CONTENT_HOST
      redirect "#{ request.scheme }://#{ PUTHTML_APP_HOST }#{ request.path }"
      return
    end

    if request.path != '/' and request.path =~ %r[/$]
      redirect request.path[0 .. -2]
      return
    end
  end

  get '/' do
    @error = flash[:error]
    @latest_documents = Document.latest(limit: 25)
    @greatest_documents = Document.greatest(limit: 25)

    # no slurping from homepage
    headers['X-Frame-Options'] = 'DENY'

    erb :'index.html', layout: true
  end

  get '/auth/twitter/callback' do
    auth = request.env["omniauth.auth"]
    user = User.first_or_new({ uid: auth["uid"] }, { created_at: Time.now })
    user.name = auth["info"]["nickname"]

    first_time = (user.new? or (user.created_at.to_i < 1387668050 and !Bucket.objects["#{ user.name }/profile.json"].exists?)) # legacy lol
    user.save

    # let's start this user off right
    if first_time
      profile_source = auth['extra']['raw_info']
      profile = Hash[* %w[name location description url].map{ |k| [k, profile_source[k]] }.flatten]

      # expand that dirty taco
      if profile['url'].present? and profile['url'] =~ /^http:\/\/t\.co\//
        uri = URI.parse profile['url']
        Net::HTTP.start(uri.host) do |http|
          http.open_timeout = 2
          http.read_timeout = 2
          req = Net::HTTP::Head.new(uri.path)
          response = http.request(req)
          profile['url'] = response['location']
        end
      end

      Document.write "#{ user.name }/profile.json", profile.to_json
    end

    user.generate_api_key
    user.save if user.dirty?

    session[:user_id] = user.id

    # after successful sign-in or sign-out
    redirect '/'
  end

  #edit htmls or whatever else
  get '/edit-put/*' do
    path = params[:splat].join('/')

    clean_path = path.sub(/\.html?$/, '').sub(/[^a-zA-Z0-9_\-.\/]/, '')

    if path != clean_path
      return redirect to ("/#{ clean_path }")
    end

    path += '.html' unless EXTNAMES_BY_MIME_TYPE.values.include?(File.extname(path))
    @document = Document.new path: path
    output = Bucket.objects[path].read rescue nil

    if output
      if current_user
        @copy = (@document.user != current_user)
        @path = path.sub %r[^[^/]+/], ''
        @output = output
        @mode = EDITOR_MODES[File.extname(path)]
        return erb :'editor.html', layout: true
      else
        flash[:error] = 'You must be signed in to edit a document.'
        redirect '/'
      end
    else
      flash[:error] = 'That page does not exist. Put it there!'
      redirect to('/')
    end
  end
   

  get '/sign-out' do
    session.delete(:user_id)
    redirect '/'
  end

  ### i.puthtml.com content host
  get '/i.puthtml/*' do
    path = params[:splat].join('/')

    #redirect to new edit url if old ?edit query exists
    if params.key? 'edit'
      return redirect to "#{ request.scheme }://#{ PUTHTML_APP_HOST }/edit-put/#{ path }"
    end

    clean_path = path.sub(/\.html?$/, '').sub(/[^a-zA-Z0-9_\-.\/]/, '')

    if path != clean_path
      return redirect to ("/#{ clean_path }")
    end

    path += '.html' unless EXTNAMES_BY_MIME_TYPE.values.include?(File.extname(path))
    @document = Document.new path: path
    output = Bucket.objects[path].read rescue nil

    if output
      @document.view!

      headers['Content-Type'] = Rack::Mime::MIME_TYPES[File.extname(path)]
      return output
    else
      flash[:error] = 'That page does not exist. Put it there!'
      redirect to('/')
    end 
  end
    
  get '/:username' do
    @user = User.first_or_new(name: params[:username])
    profile = JSON.load(Bucket.objects["#{ @user.name }/profile.json"].read) rescue nil
    profile ||= YAML.load(Bucket.objects["#{ @user.name }/profile.yml"].read) rescue nil
    @user.profile = profile if profile

    @latest_documents = Document.latest(limit: 25, user: @user)
    @greatest_documents = Document.greatest(limit: 25, user: @user)

    unless @latest_documents.nil?
      return erb :'user.html', layout: true
    end
  end
   
  get '/:username/*' do
    # content was once served from here before being moved to a seperate host
    # this will redirect old urls
    if !params[:splat].empty?
      return redirect PUTHTML_CONTENT_URL + "#{ params[:username] }/#{ params[:splat].join('/') }", 301
    end
  end
  
  post '/' do
    authenticated_user = params[:api_key].present? ? User.first(api_key: params[:api_key]) : current_user
    if authenticated_user.nil?
      @error = 'You need to sign in first!'
    else
      contents = nil
      path = nil

      if params[:file].is_a? Hash
        tmpfile = params[:file][:tempfile]
        # if this file is huge, don't read the whole thing--
        # just enough to trigger the "too large" error
        # (i'm not sure this actually gains us anything)
        contents = open(tmpfile).read(MAX_FILE_SIZE + 1)
        path = params[:path].to_s.strip.present? ? params[:path].strip : params[:file][:filename]
      elsif params[:contents]
        contents = params[:contents]
        path = params[:path]
      end

      extname = File.extname(path)
      extname = '.html' if extname == ''
      type = Rack::Mime::MIME_TYPES[extname]

      if contents
        if ACCEPTABLE_MIME_TYPES.include? type.to_s
          if contents.size <= MAX_FILE_SIZE
            path.sub! /#{ File.extname(path) }$/, ''
            path.gsub! /[^a-zA-Z0-9_\-\/]/, ''
            path.sub! %r[^#{ authenticated_user.name }/]i, ''

            path = "#{ authenticated_user.name.downcase }/#{ path }#{ EXTNAMES_BY_MIME_TYPE[type] }"

            Document.write path, contents

            redirect to("/#{ path }")
            return
          else
            @error = 'Your file is too large!'
          end
        else
          @error = 'Your file is not an acceptable type!' + " (#{ type })"
        end
      else
        @error = 'No file selected'
      end
    end

    if @error
      flash[:error] = @error
      redirect to('/')
    end
  end

  post '/settings/api-key' do
    if current_user
      current_user.generate_api_key true
      current_user.save
    end

    redirect '/'
  end

  post '/*' do
    if params[:_method] == 'delete'
      authenticated_user = params[:api_key].present? ? User.first(api_key: params[:api_key]) : current_user
      if authenticated_user.nil?
        @error = 'You need to sign in first!'
      else
        path = params[:splat].join('/')

        clean_path = path.sub(/\.html?$/, '').sub(/[^a-zA-Z0-9_\-.\/]/, '')

        if path != clean_path
          return redirect to ("/#{ clean_path }")
        end

        path += '.html' unless EXTNAMES_BY_MIME_TYPE.values.include?(File.extname(path))

        object = Bucket.objects[path]
        if object.exists?
          Document.delete path
          # todo
          # This shouldn't be displayed as an error
          # but we don't have a success state yet
          @error = 'Document deleted.'
        else
          @error = 'This document does not exist so it cannot be deleted.'
        end
      end

      flash[:error] = @error
      redirect to('/')
    end
  end
end
