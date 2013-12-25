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
require_relative 'lib/sanitizers.rb'

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/database.db")
DataMapper.finalize
DataMapper.auto_upgrade!

class PutHTML < Sinatra::Base
  use OmniAuth::Strategies::Twitter, ENV['TWITTER_CONSUMER_KEY'], ENV['TWITTER_CONSUMER_SECRET']

  configure do
    set :session_secret, ENV['COOKIE_SECRET']
    enable :sessions
  end

  set :assets_precompile, %w[*.css]
  register Sinatra::AssetPipeline

  helpers do
    def current_user
      @current_user ||= User.get(session[:user_id]) if session[:user_id]
    end
  end

  AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID']
  AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY']
  Bucket = AWS::S3.new.buckets[ENV['AWS_BUCKET_NAME']] rescue nil

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

  use Rack::Flash

  REDIS_URL = ENV['REDISCLOUD_URL']
  REDIS = if REDIS_URL
    uri = URI.parse(REDIS_URL)
    Redis.new host: uri.host, port: uri.port, password: uri.password
  else
    Redis.new
  end

  if (Bucket.present? rescue false)
    documents = Bucket.objects.map do |obj|
      next if obj.key =~ /^_legacy\// # legacy duh
      Document.new path: obj.key, updated_at: obj.last_modified
    end

    documents.compact! # just for legacy

    # start fresh
    REDIS.del(['documents'] + REDIS.keys('documents.*'))
    REDIS.zadd 'documents', documents.map{ |doc| [doc.updated_at.to_i, doc.path] }.flatten
    documents.group_by(&:user_id).each do |user_id, docs|
      next if docs.first.user.nil?
      REDIS.zadd "documents.#{ docs.first.user.name }", docs.map{ |doc| [doc.updated_at.to_i, doc.path] }.flatten
    end
  end

  before do
    if ENV['RACK_ENV'] == 'production' and ENV.key?('APP_HOST') and request.host != ENV['APP_HOST']
      redirect "#{ request.scheme }://#{ ENV['APP_HOST'] }#{ request.path }"
      return
    end

    if request.path != '/' and request.path =~ %r[/$]
      redirect request.path[0 .. -2]
      return
    end
  end

  get '/' do
    @error = flash[:error]
    @documents = REDIS.zrevrange('documents', 0, 10).map{ |path| Document.new(path: path) }
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

    session[:user_id] = user.id

    # after successful sign-in or sign-out
    redirect '/'
  end

  get '/sign-out' do
    session.delete(:user_id)
    redirect '/'
  end

  get '/:username' do
    @user = User.first_or_new(name: params[:username])
    profile = JSON.load(Bucket.objects["#{ @user.name }/profile.json"].read) rescue nil
    profile ||= YAML.load(Bucket.objects["#{ @user.name }/profile.yml"].read) rescue nil
    @user.profile = profile if profile

    @documents = REDIS.zrevrange("documents.#{ @user.name }", 0, 10).map{ |path| Document.new(path: path) }
    unless @documents.nil?
      return erb :'user.html', layout: true
    end
  end

  get '/*' do
    path = params[:splat].join('/')

    clean_path = path.sub(/\.html?$/, '').sub(/[^a-zA-Z0-9_\-.\/]/, '')

    if path != clean_path
      return redirect to ("/#{ clean_path }")
    end

    path += '.html' unless EXTNAMES_BY_MIME_TYPE.values.include?(File.extname(path))
    output = Bucket.objects[path].read rescue nil
    if output
      headers['Content-Type'] = Rack::Mime::MIME_TYPES[File.extname(path)]
      return output
    else
      flash[:error] = 'That page does not exist. Put it there!'
      redirect to('/')
    end
  end

  post '/' do
    if current_user.nil?
      @error = 'You need to sign in first!'
    else
      if params[:file].is_a? Hash
        tmpfile = params[:file][:tempfile]
        filename = params[:file][:filename]
      end

      if tmpfile and filename
        type = %x[file -b --mime-type #{ tmpfile.path }].strip
        if type == 'text/plain'
          type = Rack::Mime::MIME_TYPES[File.extname(filename).to_s]
        end

        if ACCEPTABLE_MIME_TYPES.include? type.to_s
          if tmpfile.size <= 1_048_576
            path = filename
            path = params[:path] if params[:path].to_s.strip.present?
            path.sub!(/#{ File.extname(filename) }$/, '')
            path.gsub!(/[^a-zA-Z0-9_\-\/]/, '')

            path = "#{ current_user.name.downcase }/#{ path }#{ EXTNAMES_BY_MIME_TYPE[type] }"

            Document.write path, open(tmpfile).read

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
end
