require "facets/stylize"
#require "facets/string/underscore"
#require "facets/string/demodulize"

module Og

# Add join related utility methods in SqlUtils.

module SqlUtils

  def join_object_ordering(obj1, obj2)
    if obj1.class.to_s <= obj2.class.to_s
      return obj1, obj2
    else
      return obj2, obj1, true
    end
  end

  def join_class_ordering(class1, class2)
    if class1.to_s <= class2.to_s
      return class1, class2
    else
      return class2, class1, true
    end
  end

  def build_join_name(class1, class2, postfix = nil)
    # Don't reorder arguments, as this is used in places that
    # have already determined the order they want.
    "#{Og.table_prefix}j_#{tableize(class1)}_#{tableize(class2)}#{postfix}"
  end

  def join_table(class1, class2, postfix = nil)
    first, second = join_class_ordering(class1, class2)
    build_join_name(first, second, postfix)
  end

  def join_table_index(key)
    "#{key}_idx"
  end

  #--
  # The index parameter is used in the self-join case.
  #++
  
  def join_table_key(klass, index = nil)
    klass = klass.schema_inheritance_root_class if klass.schema_inheritance_child?
    "#{klass.to_s.demodulize.underscore.downcase}#{index}_oid"
  end

  def join_table_keys(class1, class2)
    if class1 == class2
      # Fix for the self-join case.
      return join_table_key(class1), "#{join_table_key(class2, 2)}"
    else
      return join_table_key(class1), join_table_key(class2)
    end
  end

  def ordered_join_table_keys(class1, class2)
    first, second = join_class_ordering(class1, class2)
    return join_table_keys(first, second)
  end

  def join_table_info(relation, postfix = nil)

    # some fixes for schema inheritance.

    owner_class, target_class = relation.owner_class, relation.target_class
    
    raise "Undefined owner_class in #{target_class}" unless owner_class
    raise "Undefined target_class in #{owner_class}" unless target_class
    
    owner_class = owner_class.schema_inheritance_root_class if owner_class.schema_inheritance_child?
    target_class = target_class.schema_inheritance_root_class if target_class.schema_inheritance_child?

    owner_key, target_key = join_table_keys(owner_class, target_class)
    first, second, changed = join_class_ordering(owner_class, target_class)

    if changed
      first_key, second_key = target_key, owner_key
    else
      first_key, second_key = owner_key, target_key
    end

    table = (relation.table ?
      relation.table :
      join_table(owner_class, target_class, postfix)
    )

    {
      :table => table,
      :owner_key => owner_key,
      :owner_table => table(owner_class),
      :target_key => target_key,
      :target_table => table(target_class),
      :first_table => table(first),
      :first_key => first_key,
      :first_index => join_table_index(first_key),
      :second_table => table(second),
      :second_key => second_key,
      :second_index => join_table_index(second_key)
    }
  end

  # Subclasses can override this if they need a different 
  # syntax.
  #--
  # TODO: pass the correct key type!
  #++

  def create_join_table_sql(join_table_info, key_type = "integer", suffix = "NOT NULL")
    join_table = join_table_info[:table]
    first_index = join_table_info[:first_index]
    first_key = join_table_info[:first_key]
    second_key = join_table_info[:second_key]
    second_index = join_table_info[:second_index]

    sql = []

    sql << %{      
      CREATE TABLE #{join_table} (
        #{first_key} #{key_type} #{suffix},
        #{second_key} #{key_type} #{suffix},
        PRIMARY KEY(#{first_key}, #{second_key})
      )
    }.gsub(/\s+/m, ' ')

    # gmosx: not that useful?
    # sql << "CREATE INDEX #{first_index} ON #{join_table} (#{first_key})"
    # sql << "CREATE INDEX #{second_index} ON #{join_table} (#{second_key})"

    return sql
  end

end

# Extends SqlStore by adding join related methods.

class SqlStore < Store

  # Relate two objects through an intermediate join table.
  # Typically used in joins_many and many_to_many relations.

  def join(obj1, obj2, table, options = nil)
    first, second = join_object_ordering(obj1, obj2)
    first_key, second_key = ordered_join_table_keys(obj1.class, obj2.class)
    if options
      exec "INSERT INTO #{table} (#{first_key},#{second_key}, #{options.keys.join(',')}) VALUES (#{Og.quote(first.pk)},#{Og.quote(second.pk)}, #{options.values.map { |v| quote(v) }.join(',')})"
    else
      exec "INSERT INTO #{table} (#{first_key},#{second_key}) VALUES (#{Og.quote(first.pk)}, #{Og.quote(second.pk)})"
    end
  end

  # Unrelate two objects be removing their relation from the
  # join table.

  def unjoin(obj1, obj2, table)
    first, second = join_object_ordering(obj1, obj2)
    first_key, second_key = ordered_join_table_keys(obj1.class, obj2.class)
    exec "DELETE FROM #{table} WHERE #{first_key}=#{quote(first.pk)} AND #{second_key}=#{quote(second.pk)}"    
  end

end

end
