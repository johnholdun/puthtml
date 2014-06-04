class Post < ActiveRecord::Base
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
  
  belongs_to :user

  validates :contents, presence: true
  validate :acceptable_mime_type
  validate :file_small_enough
  before_save :fix_pathname

  def contents
   @contents ||= #s3 voodoo
  end

  def title
   @title ||= @path.split('/').last
  end

  def fix_pathname
    self.path.sub! /#{ File.extname(self.path) }$/, ''
    self.path.gsub! /[^a-zA-Z0-9_\-\/]/, ''
    self.path.sub! %r[^#{ self.user.name }/]i, ''

    self.path = "#{ self.user.name.downcase }/#{ self.path }#{ EXTNAMES_BY_MIME_TYPE[self.content_type] }"
  end

  def content_type
    extname = File.extname(path)
    extname = '.html' if extname == ''
    Rack::Mime::MIME_TYPES[extname]
  end

  def file_small_enough
    unless contents.size <= MAX_FILE_SIZE then
      errors.add 'Your file is too large!'
    end
  end

  def acceptable_mime_type

    unless ACCEPTABLE_MIME_TYPES.include? content_type.to_s then
      errors.add 'Your file is not an acceptable type!'
    end
  end
end
