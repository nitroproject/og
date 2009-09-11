require 'og/store/sql/utils'

module Og

module MysqlUtils
  include SqlUtils
  
  def escape(str)
    return nil unless str
    return Mysql.quote(str.to_s)
  end

  # Escape the various Ruby types.

  def quote(vals)
    vals = [vals] unless vals.is_a?(Array)
    quoted = vals.inject("") do |s, val|
      s += case val
        when Fixnum, Integer, Float
          val ? val.to_s : 'NULL'
        when String
          val ? "'#{escape(val)}'" : 'NULL'
        when Time
          val ? "'#{timestamp(val)}'" : 'NULL'
        when Date
          val ? "'#{date(val)}'" : 'NULL'
        when TrueClass, FalseClass
          val ? "'1'" : 'NULL'
        when NilClass
          "NULL"
        else
          # gmosx: keep the '' for nil symbols.
          val ? escape(val.to_yaml) : ''
      end + ','
    end
    quoted.chop!
    vals.size > 1 ? "(#{quoted})" : quoted
  end

  def quote_column(val)
    "`#{val}`"
  end
  alias_method :quote_table, :quote_column

end

end
