require "og/store/sql/utils"

module Og

module SqliteUtils

  include SqlUtils
   
  # works fine without any quote.
  #--
  # Is this verified?
  #++
  
  def quote_column(val)
    return val
  end  
  alias_method :quote_table, :quote_column

end

end
