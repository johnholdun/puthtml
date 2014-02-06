class Array
  # Return sum of the `attr` attribute for an array of objects.
  def attr_sum(attr)
    map { |e| e.respond_to?(attr) ? e.send(attr).to_i : 0 }.sum
  end
  
  def value_sum
    attr_sum :value
  end
  
  def range
    begin
      flattened_self = flatten.sort
      (flattened_self.first .. flattened_self.last)
    rescue
      nil
    end
  end
end
