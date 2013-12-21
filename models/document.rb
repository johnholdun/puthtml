class Document
  include DataMapper::Resource
  property :id,         Serial
  property :user_id,    Integer
  property :path,       String
  property :slug,       String
  property :type,       String
  property :created_at, DateTime

  belongs_to :user

  attr_accessor :user_name

  def path= new_path
    @path = new_path.sub /^\//, ''

    user_name, *middle, filename = @path.split '/'

    self.type = File.extname(filename)[1 .. -1] || 'html'
    @path.sub! /\.html$/, ''

    self.user = User.first(name: user_name.downcase)
    self.user_name = user_name if user.nil?

    self.slug = filename.sub(/\.#{ type }$/, '')
    self[:path] = @path

    path
  end

  def title
    @title ||= @path.split('/').last
  end

  def filename
    @filename ||= "#{ slug }.#{ type }"
  end
end
