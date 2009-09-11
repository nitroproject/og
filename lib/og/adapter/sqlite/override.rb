#--
# Customize the standard Sqlite3 resultset to make
# more compatible with Og.
#++

module SQLite3 # :nodoc: all

class ResultSet # :nodoc: all
  alias_method :blank?, :eof?

  def each_row
    each do |row|
      yield(row, 0)
    end
  end

  def first_value
    val = self.next[0]
    close
    return val
  end

  alias_method :fields, :columns
end

class SQLException # :nodoc: all
  def table_already_exists?
    # gmosx: any idea how to better test this?
    self.to_s =~ /table .* already exists/i
  end    
end

end
