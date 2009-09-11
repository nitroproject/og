module Og
  
# This exception is thrown when a low level error happens 
# in the store. 

class StoreException < Exception
  attr_accessor :original_exception, :info

  def initialize(original_exception, info = nil)
    @original_exception, @info = original_exception, info
  end
end

end
