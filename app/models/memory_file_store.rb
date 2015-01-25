class MemoryFileStore
  def initialize
    @files = {}
  end

  def get(key)
    @files[key]
  end

  def set(key, contents)
    @files[key] = contents
  end

  def delete(key)
    @files.delete key
  end
end
