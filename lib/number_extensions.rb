require 'rubygems'
require 'action_controller'

NumberHelperMethodNames = %w[number_to_currency number_to_human_size number_to_percentage number_to_phone number_with_delimiter number_with_precision]

# Fixnum and Bignum both inherit Integer
class Integer
  NumberHelperMethodNames.each do |method|
    define_method method.gsub(/^number_/, '') do |*args|
      ActionController::Base.helpers.send method.to_sym, self, *args
    end
  end
end

class Float
  NumberHelperMethodNames.each do |method|
    define_method method.gsub(/^number_/, '') do |*args|
      ActionController::Base.helpers.send method.to_sym, self, *args
    end
  end
end