module Og

#--
# Implement Og's automatic schema evolution features.
# Add schema evolution related methods to SqlStore.
#++

module Evolution

  #--
  # Override if needed in the actual Adapter implementation.
  #++
  
  def add_sql_field(klass, a, anno)
    info "Adding field '#{a}' to '#{klass.table}'"
    query "ALTER TABLE #{klass.table} ADD COLUMN #{field_sql_for_attribute a, anno}"
  end
  alias_method :add_sql_column, :add_sql_field
  
  #--
  # Override if needed in the actual Adapter implementation.
  #++
  
  def remove_sql_field(klass, a)
    info "Removing field '#{a}' from '#{klass.table}'"
    query "ALTER TABLE #{klass.table} DROP COLUMN #{a}"
  end
  alias_method :add_sql_column, :add_sql_field

  #--
  # Override if needed in the actual Adapter implementation.
  #++

  def rename_sql_table(_old, _new)
    info "Rename table '#{_old}' to '#{_new}'"
    query "ALTER TABLE #{_old} RENAME #{_new}"
  end
  
  # Evolve the schema (table in sql stores) for the given
  # class. Compares the fields in the database schema with
  # the serializable attributes of the given class and tries
  # to fix mismatches by adding are droping columns.
  #
  # === Evolution options
  # 
  # * :evolve_schema => :add (only add, dont remove columns)
  # * :evolve_schema => :full (add and delete columns)
  # * :evolve_schema => :warn (only emit warnings, DEFAULT_
  # * :evolve_schema => false (no evolution)
  #
  # === Example
  #
  # Og.setup(
  #   ..
  #   :evolve_schema => :full
  #   ..
  # )

  def evolve_schema(klass)
    return unless @options[:evolve_schema]
    klass = klass.table_class
    
    sql_fields = create_field_map(klass).keys
    attrs = serializable_attributes_for_class(klass)

    # Add new fields to the table.
    
    for field in attrs
      unless sql_fields.include? field
        unless @options[:evolve_schema] == :warn
          add_sql_field klass, field, annotation_for_field(klass, field)
        else
          warn "Missing field '#{field}' on table '#{klass.table}'!"
        end
      end
    end
      
    # Remove obsolete fields from the table.
   
    for field in sql_fields
      unless attrs.include? field
        if @options[:evolve_schema] == :full 
          remove_sql_field klass, field
        else
          warn "Obsolete field '#{field}' found on table '#{klass.table}'!"
        end
      end
    end   
  end

  # Renames the schema (table in sql stores) for the given
  # class. 
  #
  # === Input
  #
  # * new_schema = the new schema (Class or table name)
  # * old_schema = the old schema (Class or table name)
  #
  # === Example
  #
  # store.rename_schema(TicketArticle, Ticket::Article)
  
  def rename_schema(old_schema, new_schema)
    if old_schema.is_a? Class
      old_schema = table(old_schema)
    end

    if new_schema.is_a? Class
      new_schema = table(new_schema)
    end

    rename_sql_table(old_schema, new_schema)     
  end
  
end

SqlStore.send :include, Evolution

end

