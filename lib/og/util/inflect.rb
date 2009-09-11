require 'english/inflect'

#require 'facets/module/attr_setter'
#require 'facets/module/basename'
#require 'facets/string/to_const'

# = ORMSupport
#
# Provides a number of basc convenience methods for working with Object
# Relational Mapping.

module ORMSupport

  def self.default_key(k = "~".to_sym)
    unless k == "~".to_sym
      @default_key = k.to_s
    else
      @default_key ||= '_id'
    end
  end

  # Converts a class-esque name into a table name.

  def tablename
    to_s.gsub(/::/, '_').downcase
  end
  alias_method :table_name, :tablename
  alias_method :tableize,   :tablename

  # Converts a table name into a class name.
  #--
  # THINK: Should this return the calculated name even if the 
  # class isn't found?
  #++

  def classname
    cn = to_s.gsub(/_/, '::').camelize
    k = findclass(cn)
    return k.name if k
    return cn
  end
  alias_method :class_name, :classname

  # Like classname, but returns the actual class.
  #--
  # TODO Error if not found?
  #++
  
  def classify
    findclass(classname())
  end

  def findclass( str )
    str = str.gsub(/^::/,'')
    k = nil
    ObjectSpace.each_object(Class) { |c| (k = c;  break) if c.name.downcase == str.downcase }
    return k
  end
  private :findclass

  # This is good for generating database key/id field names from class names.
  # In essence, it demodulizes, underscores and appends 'id'.
  
  def keyname(key = nil)
    raise "This Got Called, by whom?"
    key ||= ORMSupport.default_key
    
    return self.basename.underscore << key
    
    case key.to_sym
    when :_id
      self.basename.underscore + "_id"
    when :id
      self.basename.underscore + "id"
    when :_key
      self.basename.underscore + "_key"
    when :key
      self.basename.underscore + "key"
    else
      self.basename.underscore + ORMSupport.default_key
    end
  end
  alias_method :key_name, :keyname
  alias_method :foreign_key, :keyname

end

class String
  include ORMSupport
end

class Class
  include ORMSupport
  alias_method :demodulize, :basename
end
