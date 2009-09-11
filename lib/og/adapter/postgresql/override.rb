#--
# Customize the standard Postgresql driver objects to make them
# more compatible with Og.
#++

class PGconn # :nodoc: all
  
  # Redirect notices from backend to the logger instead of stderr
  
  alias_method :initialize_pre_on_notice, :initialize
  def initialize(*args)
    initialize_pre_on_notice(*args)
    
    on_notice { |message| info message }
  end

# Check for older versions of ruby-postgres and postgres-pr

unless defined?(PGconn.server_version)
  
  # call-seq:
  #   conn.server_version -> Integer
  # 
  # The number is formed by converting the major, minor, and revision numbers
  # into two-decimal-digit numbers and appending them together. For example,
  # version 7.4.2 will be returned as 70402, and version 8.1 will be returned
  # as 80100 (leading zeroes are not shown). Zero is returned if the
  # connection is bad.
  # See also parse_version.
  
  def server_version
    @server_version ||= parse_version(exec('SHOW server_version').first_value)
  rescue PGError => e
    return 0
  end
  
  def parse_version(version)
    version.split('.').map{|v| v.rjust(2,'0') }.join.to_i
  end
  private :parse_version
  
end

end


class PGresult # :nodoc: all
  def blank?
    0 == num_tuples
  end
  
  def next
    @row_idx ||= -1
    result[@row_idx += 1]
  end

  def each_row
    result.each_with_index do |row, idx|
      yield(row, idx)
    end
  end
  
  def first_value
    val = getvalue(0, 0)
    clear
    return val
  end
  
  alias_method :close, :clear

end

class PGError # :nodoc: all
  attr_accessor :og_info
end


# Compatibility layer for postgres-pr

if defined?(PostgresPR)

class PGconn # :nodoc: all
  alias_method :query_pre_resque, :query
  alias_method :exec_old, :exec
  
  def query(*args)
    exec_old(*args)
  # postgres-pr raises NoMethodError when querying if no conn is available
  rescue RuntimeError, NoMethodError => e
    raise PGError, e.message
  end
  
  alias_method :exec, :query
  
  class << self
    alias_method :new_pre_resque, :new
    
    def new(*args)
      new_pre_resque(*args)
    rescue RuntimeError => e
      raise PGError, e.message
    end
    
    alias_method :connect, :new
  end
  
  def on_notice(&block)
    @notice_processor = block
  end
  
end

class PGError # :nodoc: all
  alias error message
end

end
