require 'pathname'
require 'fileutils'

class LocalFileStore
  def initialize path
    @path = Pathname.new path
  end

  def get(key)
    file_path = @path.join key
    File.read(file_path) if File.exists? file_path
  end

  def set(key, contents)
    file_path = @path.join key
    file_dir = File.dirname file_path
    FileUtils.mkpath(file_dir) unless File.exists? file_dir
    File.write(file_path, contents)
  end

  def delete(key)
    file_path = @path.join key
    File.delete(file_path) if File.exists? file_path
  end
end
