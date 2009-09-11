require 'og/store/sql/utils'

module Og

module OracleUtils
  include SqlUtils
  
  def self.shorten_table_name(klass)
    tbl = klass.table
    klass.set_table OracleUtils.shorten_string(tbl)
  end
  
  def build_join_name(class1, class2, postfix = nil)
    # Don't reorder arguments, as this is used in places that
    # have already determined the order they want.
    jn = "#{Og.table_prefix}j_#{tableize(class1)}_#{tableize(class2)}#{postfix}"
    OracleUtils.shorten_string(jn)
  end
  
  def self.shorten_string(str)
    str[/[a-z].{0,29}$/i]
  end
  
  def quote_column(val)
    "\"#{val}\""
  end
  
end

end