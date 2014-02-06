class Document
  include DataMapper::Resource
  property :id,         Serial
  property :user_id,    Integer
  property :path,       String
  property :slug,       String
  property :type,       String
  property :views,      Integer
  property :created_at, DateTime
  property :updated_at, DateTime

  belongs_to :user

  attr_accessor :user_name

  def path= new_path
    @path = new_path.sub /^\//, ''

    user_name, *middle, filename = @path.split '/'

    filename ||= user_name
    self.type = File.extname(filename)[1 .. -1] || 'html'
    @path.sub! /\.html$/, ''

    self.user = User.first(name: user_name.downcase)
    self.user_name = user_name if user.nil?

    self.updated_at ||= Time.at(::PutHTML::REDIS.zscore('times', path).to_i).to_datetime
    self.store_views

    self.slug = filename.sub(/\.#{ type }$/, '')
    self[:path] = @path

    path
  end

  def title
    @title ||= @path.split('/').last
  end

  def partial_path
    return @partial_path if defined? @partial_path
    user_name, *partial_path_parts, name = path.split('/')
    @partial_path = partial_path_parts.join('/')
    @partial_path = nil if @partial_path == ''
    @partial_path
  end

  def filename
    @filename ||= "#{ slug }.#{ type }"
  end

  def store_views
    self.views = ::PutHTML::REDIS.zscore('views', path).to_i
  end

  def view!
    REDIS.zincrby 'views', 1, path
    REDIS.zincrby "views.#{ user.name }", 1, path
  end

  def self.write path, contents
    ::PutHTML::Bucket.objects[path].write contents, acl: :authenticated_read
    zadd_params = [Time.now.to_i, path.sub(/\.html$/, '')]
    ::PutHTML::REDIS.zadd 'times', zadd_params
    ::PutHTML::REDIS.zadd "times.#{ path.split('/').first }", zadd_params
  end

  def self.delete path
    ::PutHTML::Bucket.objects[path].delete
    zrem_params = path.sub(/\.html$/, '')
    ::PutHTML::REDIS.zrem 'times', zrem_params
    ::PutHTML::REDIS.zrem "times.#{ path.split('/').first }", zrem_params
  end

  def self.collection key, params = {}
    params.symbolize_keys!

    params[:offset] ||= 0
    params[:limit] ||= 10

    paths = ::PutHTML::REDIS.zrevrange key, params[:offset], params[:limit]
    paths.map{ |path| Document.new path: path }
  end

  def self.latest params = {}
    params.symbolize_keys!

    key = 'times'
    key += ".#{ params.delete(:user).name }" if params[:user].is_a? User

    collection key, params
  end

  def self.greatest params = {}
    params.symbolize_keys!

    key = 'views'
    key += ".#{ params.delete(:user).name }" if params[:user].is_a? User

    collection key, params
  end

  def self.save_all
    ::PutHTML::REDIS.zrange('times', 0, -1).each do |path|
      doc = Document.first_or_new(path: path)
      doc.store_views
      doc.save
    end
  end
end
