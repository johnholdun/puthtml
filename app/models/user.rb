class User < ActiveRecord::Base
  has_many :posts

  before_create :generate_api_key

  # THIS IS DESPICABLE
  # CHANGE IT
  def profile
    @profile ||= begin
      fields = {}
      post = posts.find_by_path("#{ name }/profile.json") || posts.find_by_path("#{ name }/profile.yml")
      if post
        fields = post.parsed_contents
      end
      UserProfile.new fields
    end
  end

  def profile= profile_fields
    if profile_fields.is_a? Hash
      @profile = UserProfile.new(profile_fields)
    end
  end

  def generate_api_key force = false
    return api_key if api_key.present? and !force
    self.api_key = SecureRandom.hex 24
  end
end

class UserProfile
  def initialize new_attributes = {}
    @attributes = {}
    new_attributes.each do |key, value|
      self.send "#{ key }=", value
    end
  end

  def has? key
    @attributes.keys.include? key.to_sym
  end

  def url= new_url
    if new_url =~ /\Ahttps?:\/\/([a-zA-Z0-9.])+(\/([a-zA-Z0-9_\-?=&\.\/])*\/?)?\Z/
      @attributes[:url] = new_url
    end
  end

  def method_missing meth, *args, &block
    if meth.to_s =~ /=$/
      @attributes[meth[0 .. -2].to_sym] = args.first
    elsif @attributes.keys.include? meth
      @attributes[meth]
    else
      super
    end
  end
end