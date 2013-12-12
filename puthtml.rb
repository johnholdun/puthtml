require 'rack-flash'

class PutHTML < Sinatra::Base
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

  MIME_TYPES_BY_EXTENSION = {
    '.html' => 'text/html',
    '.htm' => 'text/html',
    '.json' => 'application/json',
    '.css' => 'text/css',
    '.js' => 'application/javascript',
    '.yml' => 'application/yaml',
    '.yaml' => 'application/yaml'
  }

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

  REDIS.lpush 'pages', Bucket.objects.sort_by{ |o| o.last_modified }[-10, 10].map{ |o| o.key.sub /\.html$/, '' }

  before do
    if request.path != '/' and request.path =~ %r[/$]
      redirect request.path[0 .. -2]
      return
    end
  end

  get '/' do
    @error = flash[:error]
    @pages = REDIS.lrange 'pages', 0, 10
    erb :'index.html'
  end

  get '/*' do
    path = params[:splat].first
    clean_path = path.sub(/\.html?$/, '').sub /[^a-zA-Z0-9_\-.]/, ''
    
    if path != clean_path
      redirect to ("/#{ clean_path }")
      return
    end

    path += '.html' if File.extname(path) == ''
    output = Bucket.objects[path].read rescue nil
    if output
      headers['Content-Type'] = MIME_TYPES_BY_EXTENSION[File.extname(path)]
      return output
    else
      flash[:error] = 'That page does not exist. Put it there!'
      redirect to('/')
    end
  end

  post '/' do
    if params[:file].is_a? Hash
      tmpfile = params[:file][:tempfile]
      name = params[:file][:filename]
    end

    if tmpfile and name
      type = %x[file -b --mime-type #{ tmpfile.path }].strip
      if type == 'text/plain'
        type = MIME_TYPES_BY_EXTENSION[File.extname(name).to_s]
      end

      if ACCEPTABLE_MIME_TYPES.include? type.to_s
        if tmpfile.size <= 1_048_576
          path = name
          path.sub! /#{ File.extname(path) }$/, ''
          path.sub! /[^a-zA-Z0-9_-]/, ''

          path += EXTNAMES_BY_MIME_TYPE[type]

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

    if @error
      flash[:error] = @error
      redirect to('/')
    else
    end
  end
end
