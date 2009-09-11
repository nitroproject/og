#--
# Customize the standard MySQL driver objects to make
# more compatible with Og.
#++

class Mysql # :nodoc: all

class Result # :nodoc: all
  def blank?
    0 == num_rows
  end

  alias_method :next, :fetch_row  

  def each_row
    each do |row|
      yield(row, 0)
    end
  end

  def first_value
    val = fetch_row[0]
    free
    return val
  end

  alias_method :close, :free

  def fields
    fetch_fields.collect { |f| f.name }
  end
end

end
