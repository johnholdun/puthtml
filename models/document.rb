class Document
  include DataMapper::Resource
  property :id,         Serial
  property :user_id,    Integer
  property :slug,       String
  property :type,       String
  property :created_at, DateTime

  belongs_to :user

  attr_accessor :user_name

  def path= new_path
    new_path.sub!(/^\//, '')
    user_name, slug = new_path.split('/')
    if slug.nil? # legacy
      slug = user_name
      user_name = nil
    end
    self.type = File.extname(slug)[1 .. -1] || 'html'
    slug.sub!(/#{ File.extname(slug) }$/, '')
    if user_name # legacy
      self.user = User.first(name: user_name.downcase)
      self.user_name = user_name if user.nil?
    end
    self.slug = slug
    path
  end

  def title
    @title ||= @path.split('/').last
  end

  def path
    @path ||= if user.nil? and user_name.nil? # legacy
      "/#{ filename.sub /\.html$/, '' }"
    else
      "/#{ user.try(:name) || user_name }/#{ filename.sub /\.html$/, '' }"
    end
  end

  def filename
    @filename ||= "#{ slug }.#{ type }"
  end
end
