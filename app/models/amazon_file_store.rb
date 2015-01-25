class AmazonFileStore
  def initialize bucket_name
    @bucket_name = bucket_name
  end

  def get(key)
    read_from_bucket(key)
  end

  def set(key, contents)
    write_to_bucket(key, contents)
  end

  def delete(key)
    delete_from_bucket(key)
  end

  private

  def bucket
    AWS::S3.new.buckets[@bucket_name] rescue nil
  end

  def bucket_object(key)
    bucket.try(:objects).try :[], key
  end

  def read_from_bucket(key)
    bucket_object(key).try :read
  end

  def write_to_bucket(key, contents)
    bucket_object(key).try :write, contents, acl: :authenticated_read
  end

  def delete_from_bucket(key)
    bucket_object(key).try :delete
  end
end
