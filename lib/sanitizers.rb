module Sanitizers
  class TagSanitizer
    def sanitize text
      result = text.gsub /<[^>]+>/, ''
      result == text ? result : sanitize(result)
    end
  end
end

class String
  def strip_tags
    Sanitizers::TagSanitizer.new.sanitize self
  end
end