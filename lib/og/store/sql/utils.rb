require 'time'

module Og

# A collection of useful SQL utilities.

module SqlUtils

  # Escape an SQL string

  def escape(str)
    return nil unless str
    return str.gsub(/'/, "''")
  end

  # Convert a ruby time to an sql timestamp.
  #--
  # TODO: Optimize this.
  #++

  def timestamp(time = Time.now)
    return nil unless time
    return time.strftime("%Y-%m-%d %H:%M:%S")
  end

  # Output YYY-mm-dd
  #--
  # TODO: Optimize this.
  #++

  def date(date)
    return nil unless date
#   return "#{date.year}-#{date.month}-#{date.mday}" 
    return date.strftime("%Y-%m-%d")
  end

  #--
  # TODO: implement me!
  #++

  def blob(val)
    val
  end

  # Parse an integer.

  def parse_int(int)
    Integer(int) if int
  rescue
    nil
  end

  # Parse a float.

  def parse_float(fl)
    Float(fl) if fl
  rescue
    nil
  end

  # Parse sql datetime
  #--
  # TODO: Optimize this.
  #++

  def parse_timestamp(str)
    return nil unless str
    return Time.parse(str)    
  end

  # Input YYYY-mm-dd
  #--
  # TODO: Optimize this.
  #++

  def parse_date(str)
    return nil unless str
    return Date.strptime(str)
  end

  # Parse a boolean
  # true, 1, t  => true
  # other       => false

  def parse_boolean(str)
    return true if (str=='true' || str=='t' || str=='1')
    return false
  end

  #--
  # TODO: implement me!!
  #++

  def parse_blob(val)
    val
  end

  # Escape the various Ruby types.

  def quote(vals)
    vals = [vals] unless vals.is_a?(Array)
    quoted = vals.inject('') do |s,val|
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
          val ? "'t'" : 'NULL'
        else
          # gmosx: keep the '' for nil symbols.
          val ? escape(val.to_yaml) : 'NULL'
      end + ','
    end
    quoted.chop!
    vals.size > 1 ? "(#{quoted})" : quoted
  end

  # Escape the Array Ruby type.

  def quote_array(val)
    case val
      when Array
        val.collect{ |v| quotea(v) }.join(',')
      else
        quote(val)
    end
  end
  alias_method :quotea, :quote_array

  # Apply table name conventions to a class name.

  def tableize(klass)
    "#{klass.to_s.gsub(/::/, "_").downcase}"
  end

  # Return the table name for the given class.
  
  def table(klass)
    return klass::OGTABLE if klass.const_defined?(:OGTABLE)
    klass.ann(:self, :sql_table) || klass.ann(:self, :table) || quote_table("#{Og.table_prefix}#{tableize(klass)}")
  end

  #--
  # The quote_table method should be overridden in:
  # ./og/lib/og/adapter/<vendor>/utils.rb
  #++
  
  def quote_column(tbl)
    raise NotImplementedError, "quote_column (alias quote_table) not set for #{self.class.name}!"
  end
  alias_method :quote_table, :quote_column
  
end

end
