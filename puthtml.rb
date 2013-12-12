require 'sinatra/base'
require 'active_support/all'

AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID']
AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY']
Bucket = AWS::S3.new.buckets[ENV['AWS_BUCKET_NAME']]

class PutHTML < Sinatra::Base
  before do
    if request.path != '/' and request.path =~ %r[/$]
      redirect request.path[0 .. -2]
      return
    end
  end

  get '/' do
    erb :'index.html'
  end

  get '/*' do
    path = params[:splat].first
    path.sub! /\.html$/, ''
    path.sub! /[^a-zA-Z0-9_-]/, ''

    output = Bucket.objects["#{ path }.html"].read rescue nil
    if output
      return output
    else
      redirect to('/')
    end
  end

  post '/' do
    if params[:file].is_a? Hash
      tmpfile = params[:file][:tempfile]
      name = params[:file][:filename]
    end

    if tmpfile and name
      type = MimeMagic.by_magic(tmpfile)
      if type == 'text/html'
        if tmpfile.size <= 1_048_576
          path = name
          path.sub! /#{ File.extname(name) }$/, ''
          path.sub! /[^a-zA-Z0-9_-]/, ''

          Bucket.objects["#{ path }.html"].write open(tmpfile).read, acl: :authenticated_read
          redirect to("/#{ path }")
          return
        else
          @error = 'Your file is too large!'
        end
      else
        @error = 'Please choose an HTML file'
      end
    else
      @error = 'No file selected'
    end

    if @error
      return erb(:'index.html')
    else
    end
  end
end
