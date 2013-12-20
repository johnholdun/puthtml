require 'omniauth'
require 'omniauth-twitter'
require 'dm-core'
require 'dm-migrations'
require 'rack-flash'
require 'active_support/all'

require_relative 'models/init'

class PutHTML < Sinatra::Base
  use OmniAuth::Strategies::Twitter, ENV['TWITTER_CONSUMER_KEY'], ENV['TWITTER_CONSUMER_SECRET']

  configure do
    set :session_secret, ENV['COOKIE_SECRET']
    enable :sessions
  end

  helpers do
    def current_user
      @current_user ||= User.get(session[:user_id]) if session[:user_id]
    end
  end

  AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID']
  AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY']
  Bucket = AWS::S3.new.buckets[ENV['AWS_BUCKET_NAME']]

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

  REDIS.ltrim('pages', -1, 0)

  REDIS.lpush('pages', Bucket.objects.sort_by{ |o| o.last_modified }[-10, 10].map{ |o| o.key.sub(/\.html$/, '') })

  before do
    if request.path != '/' and request.path =~ %r[/$]
      redirect request.path[0 .. -2]
      return
    end
  end

  get '/' do
    @error = flash[:error]
    @documents = REDIS.lrange('pages', 0, 10).map{ |path| Document.new(path: path) }
    erb :'index.html', layout: true
  end

  get '/auth/twitter/callback' do
    auth = request.env["omniauth.auth"]
    user = User.first_or_new({ uid: auth["uid"] }, { created_at: Time.now })
    user.name = auth["info"]["nickname"]
    user.save

    session[:user_id] = user.id

    # after successful sign-in or sign-out
    redirect '/'
  end

  get '/sign-out' do
    session.delete(:user_id)
    redirect '/'
  end

  get '/*' do
    path = params[:splat].join('/')

    unless (path.include?('/')) then #try user page
      @username = params[:splat].first
      @documents = REDIS.lrange('pages', 0, 10).select{ |p| p.match(/#{@username}\/.*?/)}.map { |p| Document.new(path: p) }
      unless @documents.nil?
        return erb :'user.html', layout: true
      end
    end

    clean_path = path.sub(/\.html?$/, '').sub(/[^a-zA-Z0-9_\-.\/]/, '')

    if path != clean_path
      return redirect to ("/#{ clean_path }")
    end

    path += '.html' if File.extname(path) == ''
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
        name = params[:file][:filename]
      end

      if tmpfile and name
        type = %x[file -b --mime-type #{ tmpfile.path }].strip
        if type == 'text/plain'
          type = Rack::Mime::MIME_TYPES[File.extname(name).to_s]
        end

        if ACCEPTABLE_MIME_TYPES.include? type.to_s
          if tmpfile.size <= 1_048_576
            path = name
            path.sub!(/#{ File.extname(path) }$/, '')
            path.sub!(/[^a-zA-Z0-9_-]/, '')

            path = "#{ current_user.name.downcase }/#{ path }#{ EXTNAMES_BY_MIME_TYPE[type] }"

            Bucket.objects[path].write open(tmpfile).read, acl: :authenticated_read
            REDIS.lpush 'pages', path.sub(/\.html$/, '')
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
    else
    end
  end
end

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/database.db")
DataMapper.finalize
DataMapper.auto_upgrade!
