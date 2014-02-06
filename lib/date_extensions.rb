class Date
  def to_javascript
    "new Date(#{self.to_time.utc.to_i * 1000})"
  end
  
  # When does this week start?
  def sunday
    self - self.wday
  end
  
  # When does this week end?
  def saturday
    self + 7 - self.wday - 1
  end
end