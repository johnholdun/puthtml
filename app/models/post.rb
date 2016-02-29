class Post < ActiveRecord::Base
  MAX_FILE_SIZE = 2_097_152

  MIME_TYPE = 'text/html'

  class << self
    attr_writer :file_store

    def file_store
      raise('No file store defined!') unless defined? @file_store
      @file_store
    end
  end

  belongs_to :user

  before_validation :assign_path

  validates :contents, presence: true
  validates :path, presence: true
  validates :path, uniqueness: { scope: :user_id }, on: :create
  validate :acceptable_mime_type
  validate :file_small_enough

  before_save :commit_contents
  before_save :fix_pathname

  attr_accessor :file

  def self.find_by_user_name_and_path(user_name, path)
    return unless path
    path += '.html' unless File.extname(path).present?
    Post.includes(:user).where(users: { name: user_name }, path: path).first
  end

  def contents
    @contents ||= if file.respond_to? :tempfile
      # if this file is huge, don't read the whole thing--
      # just enough to trigger the "too large" error
      # (i'm not sure this actually gains us anything)
      open(file.tempfile).read(MAX_FILE_SIZE + 1)
    else
      self[:contents]
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

  def basename
    return 'untitled' unless path
    File.basename path
  end

  def fix_pathname
    clean_path = self.path
      .sub(/#{ File.extname(self.path) }$/, '')
      .gsub(/[^a-zA-Z0-9_\-\/]/, '')

    self.path = "#{ clean_path }#{ extname }"
  end

  def content_type
    return unless path
    @content_type ||=
      begin
        extname = File.extname path
        extname = '.html' unless extname.present?
        Rack::Mime::MIME_TYPES[extname]
      end
  end

  def extname
    '.html'
  end

  def partial_path
    @partial_path ||= path.split('/')[0 .. -2].join('/') rescue ''
  end

  def path_with_user
    "#{ user.name }/#{ path }#{ '.html' unless File.extname(path).present? }"
  end

  def views
    @views ||= self[:views].to_i
  end

  def file_small_enough
    return unless contents
    unless contents.size <= MAX_FILE_SIZE
      errors.add :contents, 'Your file is too large!'
    end
  end

  def acceptable_mime_type
    unless content_type.to_s == MIME_TYPE
      errors.add :contents, 'Your file is not an acceptable type!'
    end
  end

  def mode
    return 'plain' unless content_type
    content_type.split('/').last
  end

  private

  def assign_path
    return true if self[:path].present? or frozen?
    self[:path] = file.try :original_filename
    true
  end

  def commit_contents
    self.contents = contents
    true
  end
end
