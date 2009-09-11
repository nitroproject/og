require 'og/store/sql/utils'

module Og

module PostgresqlUtils
  include SqlUtils
  
  def escape(str)
    return nil unless str
    return PGconn.escape(str.to_s)
  end

  # Blobs are actually a lot faster (and use up less 
  # storage) for large data I think, as they need not to be 
  # encoded and decoded. I'd like to have both ;-) BYTEA is 
  # easier to handle than BLOBs, but if you implement BLOBs in a way
  # that they are transparent to the user (as I did in Ruby/DBI), 
  # I'd prefer that way.
  
  def blob(val)
    val.gsub(/[\000-\037\047\134\177-\377]/) do |b|
      "\\#{ b[0].to_s(8).rjust(3, '0') }" 
    end
  end  
  
  def parse_blob(val)
    return '' unless val
    
    val.gsub(/\\(\\|'|[0-3][0-7][0-7])/) do |s|
      if s.size == 2 then s[1,1] else s[1,3].oct.chr end
    end
  end
   
  def quote_column(val)
    "\"#{val}\""
  end  
  alias_method :quote_table, :quote_column
  
end

end
