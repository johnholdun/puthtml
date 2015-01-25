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

  Bucket = AWS::S3.new.buckets[ENV['AWS_BUCKET_NAME']] rescue nil

  class << self
    attr_writer :file_store

    def file_store
      raise('No file store defined!') unless defined? @file_store
      @file_store
    end
  end

  belongs_to :user

  validates :contents, presence: true
  validates :path, presence: true
  validate :acceptable_mime_type
  validate :file_small_enough

  before_save :fix_pathname
  after_save :write_contents
  after_destroy :delete_object

  attr_writer :contents
  attr_accessor :file

  def path cached = true
    return @path if cached and defined?(@path) and @path.present?

    self[:path] = file.try(:original_filename) unless self[:path].present? or self.frozen?

    @path = self[:path]
  end

  def contents
    @contents ||= if file.respond_to? :tempfile
      # if this file is huge, don't read the whole thing--
      # just enough to trigger the "too large" error
      # (i'm not sure this actually gains us anything)
      open(file.tempfile).read(MAX_FILE_SIZE + 1)
    else
      self.class.file_store.get path
    end
  end

  def parsed_contents
    @parsed_contents ||= if content_type == 'application/json'
      JSON.load(contents) rescue contents
    # elsif content_type == 'application/yaml'
    #   Yaml.load contents
    else
      contents
    end
  end

  def title
    @title ||= path.to_s.split('/').last
  end

  def title_without_extension
    title.sub(/\.[^.]+$/, '')
  end

  def extension
    title.sub %r[^#{ title_without_extension }], ''
  end

  def fix_pathname
    clean_path = self.path
      .sub(/#{ File.extname(self.path) }$/, '')
      .gsub(/[^a-zA-Z0-9_\-\/]/, '')
      .sub(%r[^#{ self.user.name }/]i, '')

    self.path = "#{ self.user.name.downcase }/#{ clean_path }#{ EXTNAMES_BY_MIME_TYPE[self.content_type] }"
  end

  def content_type
    return @content_type if defined? @content_type
    extname = File.extname(path)
    extname = '.html' unless extname.present?

    @content_type = Rack::Mime::MIME_TYPES[extname]
  end

  def partial_path
    @partial_path ||= path.split('/')[1 .. -2].join('/') rescue ''
  end

  def views
    @views ||= self[:views].to_i
  end

  def file_small_enough
    unless contents.size <= MAX_FILE_SIZE
      errors.add 'Your file is too large!'
    end
  end

  def acceptable_mime_type
    unless ACCEPTABLE_MIME_TYPES.include? content_type.to_s
      errors.add 'Your file is not an acceptable type!'
    end
  end

  def write_contents
    self.class.file_store.set path(false), contents
  end

  def delete_object
    self.class.file_store.delete(path) if path.present?
  end
end
