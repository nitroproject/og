
class OCI8::Cursor # :nodoc: all
  def blank?
    0 == row_count
  end
  
  alias_method :next, :fetch
  
  def fields
    get_col_names.map {|x| x.downcase }
  end

  def each_row
    idx = 0
    while row = fetch
      yield(row, idx)
      idx += 1
    end
  end
  
  def first_value
    fetch[0]
  end

end