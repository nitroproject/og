require "facets/module/ancestor"
require "facets/class/subclasses"

require "og/store"
require "og/store/sql/utils"
require "og/store/sql/join"
require "og/store/sql/evolution"

module Og

module SqlEnchantmentClassMethods

  def set_table(table_name)
    meta = (class << self; self; end)
    meta.send(:define_method, :table) do
      return table_name
    end
    meta.send(:alias_method, :schema, :table)
  end

  attr_accessor :store

  def og_allocate(res, row = 0)
    if schema_inheritance?
      begin
        Object.constant(res["ogtype"]).allocate
      rescue TypeError => e
        # FIXME: use res['ogtype'] here, this is slow!
        # But res['ogtype'] isn't implemented in -pr and some mysql exts,
        # create compat layer
        col = nil
        ogmanager.with_store do |s|
          col = s.create_field_map(self)[:ogtype]
        end
        Object.constant(res[col]).allocate
      ensure
        res.close if res.respond_to?(:close)
      end
    else
      self.allocate
    end
  end
end

module SqlEnchantmentNoPolymorphClassMethods
  def field_for_attribute(a, anno)
    (f = anno[:field]) ? f : a
  end

  def set_field_map(map)
    define_method(:field_map) do
      return map.dup
    end
  end
end

module SqlEnchantmentMixin

  def self.included(base)
    base.extend(SqlEnchantmentNoPolymorphClassMethods)
  end

  def store
    return self.class.store
  end

  def field_for_attribute(a, anno)
    (f = anno[:field]) ? f : a
  end

  def og_create_schema(store)
    if Og.create_schema
      unless self.class.schema_inheritance_child?
        store.create_table(self.class)
        store.create_table_indices(self.class)
        store.create_table_joins(self.class)
      end
      store.evolve_schema(self.class)
    end
  end

  def og_insert(store)
    inserts = {}

    create_primary_key() if respond_to?(:create_primary_key)

    for a in self.class.serializable_attributes
      anno = self.class.ann(a)
      field = field_for_attribute(a, anno)
      a = instance_variable_get("@#{a}")
      inserts[field] = store.write_attr(a, anno)
    end

    # If the class participates in STI, automatically insert
    # an ogtype serializable attribute.

    if self.class.schema_inheritance?
      self.ogtype = self.class.name
      inserts[:ogtype] = store.quote(self.class.name)
    end

    pk_new = store.insert(self.class, inserts)
    self.pk = pk_new unless self.pk
  end

  def og_update(store, options = nil)
    updates = {}
    pk_field = self.class.primary_key

    self.class.serializable_attributes.reject { |a| a == pk_field }.each do |a|
      anno = self.class.ann(a)
      field = field_for_attribute a, anno
      a = instance_variable_get("@#{a}")
      updates[field.to_s] = store.write_attr(a, anno)
    end

    pk = instance_variable_get("@#{pk_field}")
    sql = store.update_sql(self.class, pk, updates)
    sql << " AND #{options[:condition]}" if options and options[:condition]
    changed = store.sql_update(sql)
    return changed
  end

  # Delete current obj recursively.  This also deletes all objects beloging to
  # the current object and all entries in join classes.
  #---
  # Note: Jo:  Leave deleting in this order: first the relations, then the obj
  # itself, this prevents good database which have constraints (like psql)
  # from throwing an error due to unresolved relationships.
  #+++

  def og_delete(store, cascade = true)
    pk_field = self.class.primary_key
    pk_field = self.class.ann(pk_field, :field) || pk_field
    pk = instance_variable_get("@#{pk_field}")

    transaction_raise do |tx|
      if cascade && descendants = self.class.ann(:self, :descendants)
        descendants.each do |descendant|
          case descendant
          when ManyToMany
            # delete all entries in the join table pointing to current obj
            tx.exec "DELETE FROM #{descendant.join_table} WHERE #{descendant.owner_key}=#{store.quote(pk)}"
          when BelongsTo
            # delete all objecs belonging to the current obj
            descendant.owner_class.find(:where => "#{descendant.foreign_key} = #{store.quote(pk)}", :extra_condition => nil).each {|x| x.delete }
          end
        end
      end
      # delete obj itself
      tx.exec "DELETE FROM #{self.class.table} WHERE #{pk_field}=#{store.quote(pk)}"
    end
  end

  def field_map
    raise NotImplementedError, "field_map not set for #{self.class.name}!"
  end

  def og_read(res, row = 0, offset = 0)
    attrs = self.class.instance_attributes

    for a in attrs
      anno = self.class.ann(a)

      f = anno[:field] ? anno[:field] : a

      if col = field_map[f]
        instance_variable_set("@#{a}", store.read_attr(anno, res, col, offset))
      end
    end
  end
end

# The base implementation for all SQL stores. Reused by all
# SQL adapters.
class SqlStore < Store

  # The connection to the SQL backend.
  attr_accessor :conn

  # Ruby type <-> SQL type mappings.
  attr_accessor :typemap

  # Initialize the store.
  #--
  # Override in the adapter.
  #++
  def initialize(options)
    super

    # The default Ruby <-> SQL type mappings, should be valid
    # for most RDBM systems.
    @typemap = {
      Integer => "integer",
      Fixnum => "integer",
      Float => "float",
      String => "text",
      Time => "timestamp",
      Date => "date",
      TrueClass => "boolean",
      Object => "text",
      Array => "text",
      Hash => "text"
    }
  end

  #--
  # Override in the adapter.
  #++

  def close
    @conn.close
    super
  end

  # Creates the database where Og managed objects are
  # serialized.
  #--
  # Override in the adapter.
  #++

  def create_db(options)
    info "Created database '#{options[:name]}'"
  end

  # Destroys the database where Og managed objects are
  # serialized.
  #--
  # Override in the adapter.
  #++

  def destroy_db(options)
    info "Dropped database '#{options[:name]}'"
  end
  alias_method :drop_db, :destroy_db

  # The type used for default primary keys.

  def primary_key_type
    "integer PRIMARY KEY"
  end

  # Force the creation of a primary key class.

  def force_primary_key(klass)
    # Automatically add an :oid serializable field if none is
    # defined and no other primary key is defined.
    #
    # Make the primary key a READ-ONLY attribute for extra
    # security. For example, avoid the typical:
    #
    # if user.oid = xxx
    if klass.primary_key == :oid and !klass.instance_attributes.include?(:oid)
      klass.attr_reader :oid, Fixnum, :sql => primary_key_type
    end
  end

  # Performs SQL related enchanting to the class. This method
  # is further extended in more specialized adapters to add
  # backend specific enchanting.
  #
  # Defines:
  # * the table constant, and .table / .schema aliases.
  # * the index method for defing sql indices.
  # * precompiles the object lifecycle callbacks.

  def enchant(klass, manager)
    # setup the table where this class is mapped.
    # FIXME: jl: Remove references to table, then remove these 5 lines

    if klass.schema_inheritance_child?
      klass.const_set "OGTABLE", table(klass.schema_inheritance_root_class) unless defined? klass::OGTABLE
    else
      klass.const_set "OGTABLE", table(klass) unless defined? klass::OGTABLE
    end

    # Define table and schema aliases for table.

    klass.extend SqlEnchantmentClassMethods
    klass.set_table(klass::OGTABLE)

    klass.store = self

    # Perform base store enchantment.
    super

    unless klass.polymorphic_parent?
      # precompile class specific lifecycle methods.
      unless klass.ancestors.include? SqlEnchantmentMixin
        klass.include SqlEnchantmentMixin
      end

      # create the table if needed.
      klass.allocate.og_create_schema(self)
      klass.set_field_map(create_field_map(klass))
    end
  end

  # :section: Lifecycle methods.

  # Loads an object from the store using the primary key.
  # Returns nil if the passes pk is nil.

  def load(pk, klass)
    return nil unless pk

    sql = "SELECT * FROM #{klass.table} WHERE #{pk_field klass}=#{quote(pk)}"
    sql << " AND ogtype='#{klass}'" if klass.schema_inheritance_child?
    res = query sql
    read_one(res, klass)
  end
  alias_method :exist?, :load

  # Reloads an object from the store.
  # Returns nil if the passes pk is nil.

  def reload(obj, pk)
    return nil unless pk

    klass = obj.class
    raise "Cannot reload unmanaged object" unless obj.saved?
    sql = "SELECT * FROM #{klass.table} WHERE #{pk_field klass}=#{quote(pk)}"
    sql << " AND ogtype='#{klass}'" if klass.schema_inheritance_child?
    res = query sql
    res_next = res.next
    raise Og::Deleted, "#{obj.class}[#{pk}]" if res_next.nil?
    obj.og_read(res_next, 0)
  ensure
    res.close if res
  end

  # If an attributes collection is provided, only updates the
  # selected attributes. Pass the required attributes as symbols
  # or strings.
  #--
  # gmosx, THINK: condition is not really useful here :(
  #++

  def update(obj, options = nil)
    if options and attrs = options[:only]
      if attrs.is_a?(Array)
        set = []
        for a in attrs
          set << "#{a}=#{quote(obj.send(a))}"
        end
        set = set.join(',')
      else
        set = "#{attrs}=#{quote(obj.send(attrs))}"
      end
      sql = "UPDATE #{obj.class.table} SET #{set} WHERE #{pk_field obj.class}=#{quote(obj.pk)}"
      sql << " AND #{options[:condition]}" if options[:condition]
      sql_update(sql)
    else
      obj.og_update(self, options)
    end
  end

  # More generalized method, also allows for batch updates.
  def update_by_sql(target, set, options = nil)
    set = set.gsub(/@/, '')

    if target.is_a? Class
      sql = "UPDATE #{target.table} SET #{set} "
      sql << " WHERE #{options[:condition]}" if options and options[:condition]
      sql_update(sql)
    else
      sql = "UPDATE #{target.class.table} SET #{set} WHERE #{pk_field target.class} = #{quote(target.pk)}"
      sql << " AND #{options[:condition]}" if options and options[:condition]
      sql_update(sql)
    end
  end

  # Find a collection of objects.
  #
  # Examples:
  #   User.find(:condition  => 'age > 15', :order => 'score ASC', :offet => 10, :limit =>10)
  #   Comment.find(:include => :entry)

  def find(options)
    klass = options[:class]
    sql = resolve_options(klass, options)
    read_all(query(sql), klass, options)
  end

  # Find one object.

  def find_one(options)
    klass = options[:class]
    # gmosx, THINK: should not set this by default.
    # options[:limit] ||= 1
    sql = resolve_options(klass, options)
    read_one(query(sql), klass, options)
  end

  # Perform a custom sql query and deserialize the
  # results.

  def select(sql, klass, options = {})
    sql = "SELECT * FROM #{klass.table} " + sql unless sql =~ /SELECT/i
    read_all(query(sql), klass, options)
  end
  alias_method :find_by_sql, :select

  # Specialized one result version of select.

  def select_one(sql, klass, options = {})
    sql = "SELECT * FROM #{klass.table} " + sql unless sql =~ /SELECT/i
    read_one(query(sql), klass)
  end
  alias_method :find_by_sql_one, :select_one

  # Perform an aggregation or calculation over query results.
  # This low level method is used by the Entity
  # calculation / aggregation methods.
  #
  # Options
  #   :field = the return type.
  #
  # Example
  #   calculate 'COUNT(*)'
  #   calculate 'MIN(age)'
  #   calculate 'SUM(age)', :group => :name

  def aggregate(term = "COUNT(*)", options = {})
    # Leave this .dup here, causes problems because options are changed
    options = options.dup

    klass = options[:class]

    # Rename search term, SQL92 but _not_ SQL89 compatible
    options = {
      :select => "#{term} AS #{term[/^\w+/]}"
    }.update(options)

    unless options[:group] || options[:group_by]
      options.delete(:order)
      options.delete(:order_by)
    end
    sql = resolve_options(klass, options)

    if field = options[:field]
      return_type = klass.ann(field, :class) || Integer
    else
      return_type = Integer
    end

    if options[:group] || options[:group_by]
      # This is an aggregation, so return the calculated values
      # as an array.
      values = []
      res = query(sql)
      res.each_row do |row, idx|
        values << type_cast(return_type, row[0])
      end
      return values
    else
      return type_cast(return_type, query(sql).first_value)
    end
  end
  alias_method :calculate, :aggregate

  # Perform a count query.

  def count(options = {})
    calculate('COUNT(*)', options).to_i
  end

  # Delete all instances of the given class from the backend.

  def delete_all(klass)
    sql = "DELETE FROM #{klass.table}"
    sql << " WHERE ogtype='#{klass}'" if klass.schema_inheritance? and not klass.schema_inheritance_root?
    exec sql
  end

  # :section: Misc methods.

  # Create the SQL table where instances of the given class
  # will be serialized.

  def create_table(klass)
    fields = fields_for_class(klass)

    sql = "CREATE TABLE #{klass.table} (#{fields.join(', ')}"

    # Create table constraints.

    if constraints = klass.ann(:self, :sql_constraint)
      sql << ", #{constraints.join(', ')}"
    end

    # Set the table type (Mysql default, InnoDB, Hash, etc)

    if table_type = @options[:table_type]
      sql << ") TYPE = #{table_type};"
    else
      sql << ")"
    end

    begin
      exec(sql, false)
      info "Created table #{klass.table}."
    rescue Object => ex
      if table_already_exists_exception? ex
        # Don't return yet. Fall trough to also check for the
        # join table.
      else
        handle_sql_exception(ex, sql)
      end
    end
  end

  # Create indices.
  #
  # An example index definition:
  #
  # classs MyClass
  #   attr_accessor :age, Fixnum, :index => true, :pre_index => ...,
  #                 :post_index => ...
  # end

  def create_table_indices(klass)
    for idx in sql_indices_for_class(klass)
      anno = klass.ann(idx)
      idx = idx.to_s
      pre_sql, post_sql = klass.ann(idx, :pre_index), klass.ann(idx, :post_index)
      idxname = idx.gsub(/ /, "").gsub(/,/, "_").gsub(/\(.*\)/, "")
      sql = "CREATE #{pre_sql} INDEX #{klass.table}_#{idxname}_idx #{post_sql} ON #{klass.table} (#{idx})"
      exec(sql)
    end
  end

  # Create join tables if needed. Join tables are used in
  # 'many_to_many' relations.

  def create_table_joins(klass)
    if join_tables = klass.ann(:self, :join_tables)
      for info in join_tables
        begin
          # UGGLY hack!
          key_type = klass.ann(:oid, :sql).split(" ").first
          create_join_table_sql(info, key_type).each do |sql|
            exec(sql, false)
          end
          debug "Created join table '#{info[:table]}'." if $DBG
        rescue Object => ex
          if table_already_exists_exception? ex
            debug "Join table already exists" if $DBG
          else
            raise
          end
        end
      end
    end
  end

  # Drop the sql table where objects of this class are
  # persisted.

  def drop_table(klass)
    # Remove leftover data from some join tabkes.
    klass.relations.each do |rel|
      if rel.class.to_s == "Og::JoinsMany" and rel.join_table
        target_class =  rel.target_class
        exec "DELETE FROM #{rel.join_table}"
      end
    end
    exec "DROP TABLE #{klass.table}"
  end
  alias_method :destroy, :drop_table
  alias_method :drop_schema, :drop_table

  # Perform an sql query with results.

  def query(sql, rescue_exception = true)
    debug(sql) if $DBG
    return query_statement(sql)
  rescue Object => ex
    if rescue_exception
      handle_sql_exception(ex, sql)
    else
      raise
    end
  end

  #--
  # Override.
  #++

  def query_statement(sql)
    return @conn.query(sql)
  end

  # Perform an sql query with no results.

  def exec(sql, rescue_exception = true)
    debug(sql) if $DBG
    exec_statement(sql)
  rescue Object => ex
    if rescue_exception
      handle_sql_exception(ex, sql)
    else
      raise
    end
  end

  #--
  # Override.
  #++

  def exec_statement(sql)
    return @conn.exec(sql)
  end

  # Gracefully handle a backend exception.

  def handle_sql_exception(ex, sql = nil)
    error "DB error #{ex}, [#{sql}]"
    error ex.backtrace.join("\n")
    raise StoreException.new(ex, sql) if Og.raise_store_exceptions

    # FIXME: should return :error or something.
    return nil
  end

  # Perform an sql update, return the number of updated rows.
  #--
  # Override
  #++

  def sql_update(sql)
    exec(sql)
    # return affected rows.
  end

  # Return the last inserted row id.
  #--
  # Override
  #--

  def last_insert_id(klass)
    # return last insert id
  end

  # Resolve the finder options. Also takes scope into account.
  # This method handles among other the following cases:
  #
  # User.find :condition => "name LIKE 'g%'", :order => 'name ASC'
  # User.find :where => "name LIKE 'g%'", :order => 'name ASC'
  # User.find :sql => "WHERE name LIKE 'g%' ORDER BY name ASC"
  # User.find :condition => [ 'name LIKE ?', 'g%' ], :order => 'name ASC', :limit => 10
  #
  # If an array is passed as a condition, use prepared statement
  # style escaping. For example:
  #
  # User.find :condition => [ 'name = ? AND age > ?', 'gmosx', 12 ]
  #
  # Proper escaping is performed to avoid SQL injection attacks.
  #--
  # FIXME: cleanup/refactor, this is an IMPORTANT method.
  #++

  def resolve_options(klass, options)
    # Factor in scope.
    if scope = klass.get_scope
      scope = scope.dup
      scond = scope.delete(:condition)
      scope.update(options)
      options = scope
    end

    if sql = options[:sql]
      sql = "SELECT * FROM #{klass.table} " + sql unless sql =~ /SELECT/i
      return sql
    end

    tables = [klass::table]

    if included = options[:include]
      join_conditions = []

      for name in [included].flatten
        if rel = klass.relation(name.to_s)
          target_table = rel[:target_class]::table
          tables << target_table

          if rel.is_a?(JoinsMany)
            tables << rel[:join_table]
            owner_key, target_key = nil
            klass.ogmanager.with_store do |s|
              owner_key, target_key = s.join_table_keys(klass, rel[:target_class])
            end
            join_conditions << "#{rel.join_table}.#{owner_key}=#{klass.table}.#{rel.owner_class.primary_key} AND #{rel.join_table}.#{target_key}=#{rel.target_class.table}.#{rel.target_class.primary_key}"
          else
            join_conditions << "#{klass::table}.#{rel.foreign_key}=#{target_table}.#{rel.target_class.primary_key}"
          end
        else
          raise "Unknown relation name"
        end
      end

      fields = options[:select] || tables.collect { |t| "#{t}.*" }.join(',')

      update_condition options, join_conditions.join(" AND ")
    elsif fields = options[:select]
      fields = fields.map {|f| f.to_s}.join(", ")
    else
      fields = "*"
    end

    if join_table = options[:join_table]
      tables << join_table
      update_condition options, options[:join_condition]
    end

    # Factor in scope in the conditions.
    update_condition(options, scond) if scond

    # where is just an alias, put to :condition
    update_condition(options, options.delete(:where))

    # add extra conditions
    update_condition(options, options.delete(:extra_condition))

    # rp: type is not set in all instances such as Class.first
    # so this fix goes here for now.
    if ogtype = options[:type] || (klass.schema_inheritance_child? ? "#{klass}" : nil)
      update_condition options, "ogtype='#{ogtype}'"
    end

    sql = "SELECT #{fields} FROM #{tables.join(',')}"

    if condition = options[:condition]
      # If an array is passed as a condition, use prepared
      # statement style escaping.
      if condition.is_a?(Array)
        condition = prepare_statement(condition)
      end

      sql << " WHERE #{condition}"
    end

    if group = options[:group] || options[:group_by]
      sql << " GROUP BY #{group}"
    end

    if order = options[:order] || options[:order_by]
      sql << " ORDER BY #{order}"
    end

    resolve_limit_options(options, sql)

    if extra = options[:extra] || options[:extra_sql]
      sql << " #{extra}"
    end

    return sql
  end

  #takes an array, the first parameter of which is a prepared statement
  #style string; this handles parameter escaping.

  def prepare_statement(condition)
    args = condition.dup
    str = args.shift
    # ? handles a single type.
    # ?* handles an array.
    args.each { |arg| str.sub!(/\?\*/, quotea(arg)); str.sub!(/\?/, quote(arg)) }
    condition = str
  end

  # Subclasses can override this if they need some other order.
  # This is needed because different backends require different
  # order of the keywords.

  def resolve_limit_options(options, sql)
    if limit = options[:limit]
      sql << " LIMIT #{limit}"

      if offset = options[:offset]
        sql << " OFFSET #{offset}"
      end
    end
  end

  # :section: Utility methods for serialization/deserialization.

  # Return either the serializable attributes for the class or,
  # in the case of schema inheritance, all of the serializable
  # attributes of the class hierarchy, starting from the schema
  # inheritance root class.

  def serializable_attributes_for_class(klass)
    attrs = klass.serializable_attributes
    klass.table_class.each_schema_child do |desc|
      attrs.concat(desc.serializable_attributes)
    end
    return attrs.map{|x|x.to_sym}.uniq
  end

  # Return the SQL table field for the given serializable
  # attribute. You can override the default field name by
  # annotating the attribute with a :field annotation.

  def field_for_attribute(a, anno)
    (f = anno[:field]) ? f : a
  end

  def field_sql_for_attribute(a, anno)
    field = quote_column("#{field_for_attribute(a, anno)}")

    if anno[:sql]
      field << " #{anno[:sql]}"
    else
      field << " #{anno[:sql_type] || sql_type_for_class(anno[:class])}"
      field << " UNIQUE" if anno[:unique]
      field << " DEFAULT #{quote(anno[:default])}" if anno[:default]
      field << " NOT NULL" if anno[:default] || anno[:null] == false
      field << " #{anno[:extra_sql]}" if anno[:extra_sql]
    end

    return field
  end

  def insert(klass, inserts)
    exec(insert_sql(klass, inserts))
    if inserts[:oid] != "NULL"
      return inserts[:oid]
    else
      return last_insert_id(klass)
    end
  end

  def insert_sql(klass, inserts)
    fields = []
    values = []

    inserts.each_pair do |field,value|
      fields << quote_column(field)
      values << value
    end

    fields = fields.join(', ')
    values = values.join(', ')

    return "INSERT INTO #{klass.table} (#{fields}) VALUES (#{values})"
  end

  def update_sql(klass, pk, updates)
    updates = updates.map do |key, value|
      quote_column(key) + "=" + value
    end.join(', ')

    pk_field = klass.primary_key
    pk_field = klass.ann(pk_field, :field) || pk_field

    sql = "UPDATE #{klass.table} SET #{updates} WHERE #{pk_field}=#{quote(pk)}"
    return sql
  end


  # Generate code to serialize an attribute to an SQL table
  # field.
  # YAML is used (instead of Marshal) to store general Ruby
  # objects to be more
  # portable.
  #
  # Input:
  # * s = attribute symbol
  # * a = attribute annotations
  #--
  # No need to optimize this, used only to precalculate code.
  # FIXME: add extra handling for float.
  #++

  def write_attr_integer(value)
    value.to_s.empty? ? 'NULL' : value.to_s
  end

  def write_attr_float(value)
    value.to_s
  end

  def write_attr_string(value)
    "'#{self.class.escape(value)}'"
  end

  def write_attr_time(value)
    "'#{self.class.timestamp(value)}'"
  end

  def write_attr_date(value)
    "'#{self.class.date(value)}'"
  end

  def write_attr_boolean(value)
    value ? "'t'" : "'f'"
  end

  def write_attr_blob(value)
    "'#{self.class.escape(self.class.blob(value))}'"
  end

  def write_attr_other(value)
    return value ? "'#{self.class.escape(value.to_yaml)}'" : "''"
  end

  def write_attr_nil
    'NULL'
  end

  def write_attr(value, anno)
    store = self.class
    result = nil
    if anno[:class].ancestor? Integer
      result = write_attr_integer(value)
    elsif anno[:class].ancestor? Float
      result = write_attr_float(value)
    elsif anno[:class].ancestor? String
      result = write_attr_string(value)
    elsif anno[:class].ancestor? Time
      result = write_attr_time(value)
    elsif anno[:class].ancestor? Date
      result = write_attr_date(value)
    elsif anno[:class].ancestor? TrueClass
      result = write_attr_boolean(value)
    elsif anno[:class].ancestor? Og::Blob
      result = write_attr_blob(value)
    else
      # keep the '' for nil symbols.
      return write_attr_other(value)
    end

    if value.nil?
      return write_attr_nil
    end

    return result
  end


  # Generate code to deserialize an SQL table field into an
  # attribute. Get the fields from the database table.
  # Also handles the change of ordering of the fields in the
  # table.
  #
  # To ignore a database field use the ignore_fields annotation
  # ie,
  #
  # class Article
  #   ann :self, :ignore_fields => [ :tsearch_idx, :ext_field ]
  # end
  #
  # other aliases for ignore_fiels: ignore_field, ignore_column.
  #--
  # Even though great care has been taken to make this
  # method reusable, overide if needed in your adapter.
  #++

  def read_attr(anno, res, col, offset = 0)
    if anno[:class].ancestor? Integer
      self.class.parse_int(res[col + offset])
    elsif anno[:class].ancestor? Float
      self.class.parse_float(res[col + offset])
    elsif anno[:class].ancestor? String
      res[col + offset]
    elsif anno[:class].ancestor? Time
      self.class.parse_timestamp(res[col+ offset])
    elsif anno[:class].ancestor? Date
      self.class.parse_date(res[col + offset])
    elsif anno[:class].ancestor? TrueClass
      self.class.parse_boolean(res[col + offset])
    elsif anno[:class].ancestor? Og::Blob
      self.class.parse_blob(res[col + offset])
    else
      if res[col+offset].nil? or res[col+offset].empty?
        return nil
      else
        return YAML::load(res[col + offset])
      end
    end
  end

  #--
  # Create a hash that maps fields to ordered columns.
  #++

  # Create the fields that correspond to the class serializable
  # attributes. The generated fields array is used in
  # create_table.
  #
  # If the property has an :sql annotation this overrides the
  # default mapping. If the property has an :extra_sql annotation
  # the extra sql is appended after the default mapping.

  def annotation_for_field(klass, a)
    anno = klass.ann(a)
    if klass.schema_inheritance?
      for desc in klass.schema_inheritance_root_class.descendents
        anno = desc.ann(a).merge(anno)
        # JL: anno clashes should perhaps fail in this case.
        # I'm further thinking that the fields_for and sql_for_klass
        # stuff should be pushed into Entity, and SchemaInheritance
        # should alter them.  Otherwise we'll be chasing STI
        # around with conditionals all over the source
      end
    end
    return anno
  end

  def fields_for_class(klass)
    fields = []
    attrs = serializable_attributes_for_class(klass)

    for a in attrs
      anno = annotation_for_field(klass, a)
      fields << field_sql_for_attribute(a, anno)
    end

    return fields
  end

  # Returns the SQL indexed serializable attributes for the
  # given class.

  def sql_indices_for_class(klass)
    indices = []

    for a in klass.serializable_attributes
      indices << a if klass.ann(a, :index)
    end

    return indices
  end

  # Return the SQL type for the given Ruby class.

  def sql_type_for_class(klass)
    @typemap[klass]
  end

  def create_field_map(klass, rebuild = true)
    unless map = klass.instance_variable_get("@field_map")
      real_klass = klass.table_class

      sql = "SELECT * FROM #{real_klass::OGTABLE}"
      resolve_limit_options({:limit => 1}, sql)
      res = query(sql)

      map = {}

      # Check if the field should be ignored.
      ignore = klass.ann(:self, :ignore_fields)

      res.fields.each_with_index do |f, i|
        field_name = f.to_sym
        unless (ignore and ignore.include?(field_name))
          map[field_name] = i
        end
      end

      klass.instance_variable_set("@field_map", map)
    end

    return map
  ensure
    res.close if res
  end

  # Generates the SQL field of the primary key for this class.

  def pk_field(klass)
    pk = klass.primary_key
    return klass.ann(pk, :field) || pk
  end

  def type_cast(klass, val)
    typemap = {
      Time => :parse_timestamp,
      Date => :parse_date,
      TrueClass => :parse_boolean
    }

    if method = typemap[klass]
      send(method, val)
    else
      Integer(val) rescue Float(val) rescue raise "No conversion for #{klass} (#{val.inspect})"
    end
  end

  # :section: Deserialization methods.

  # Read a field (column) from a result set row.

  def read_field
  end

  # Dynamicaly deserializes a result set row into an object.
  # Used for specialized queries or join queries. Please
  # note that this deserialization method is slower than the
  # precompiled og_read method.
  #--
  # TODO: Optimize this!!
  #++

  def read_row(obj, res, res_row, row)
    res.fields.each_with_index do |field, idx|
      anno = obj.class.ann(field.to_sym)
      obj.instance_variable_set "@#{field}", read_attr(anno, res_row, idx)
    end
  end

  # Deserialize the join relations.

  def read_join_relations(obj, res_row, row, join_relations)
    offset = obj.class.serializable_attributes.size

    for rel in join_relations
      rel_obj = rel[:target_class].og_allocate(res_row, row)
      rel_obj.og_read(res_row, row, offset)
      offset += rel_obj.class.serializable_attributes.size
      obj.instance_variable_set("@#{rel[:name]}", rel_obj)
    end
  end

  # Deserialize one object from the ResultSet.

  def read_one(res, klass, options = nil)
    return nil if res.blank?

    if options and join_relations = options[:include]
      join_relations = [join_relations].flatten.collect do |n|
        klass.relation(n)
      end
    end

    res_row = res.next
    # causes STI classes to come back as the correct child class
    # if accessed from the superclass.
    if klass.schema_inheritance?
      klass = Og::Model::model_from_string(res_row[res.fields.index('ogtype')])
    end
    obj = klass.og_allocate(res_row, 0)

    if options and options[:select]
      read_row(obj, res, res_row, 0)
    else
      obj.og_read(res_row)
      read_join_relations(obj, res_row, 0, join_relations) if join_relations
    end

    return obj

  ensure
    res.close
  end

  # Deserialize all objects from the ResultSet.

  def read_all(res, klass, options = nil)
    return [] if res.blank?

    if options and join_relations = options[:include]
      join_relations = [join_relations].flatten.collect do |n|
        klass.relation(n)
      end
    end

    objects = []

    if options and options[:select]
      res.each_row do |res_row, row|
        obj = klass.og_allocate(res_row, row)
        read_row(obj, res, res_row, row)
        objects << obj
      end
    else
      res.each_row do |res_row, row|
        obj = klass.og_allocate(res_row, row)
        obj.og_read(res_row, row)
        read_join_relations(obj, res_row, row, join_relations) if join_relations
        objects << obj
      end
    end

    return objects

  ensure
    res.close
  end

  # Helper method that updates the condition string.

  def update_condition(options, cond, joiner = 'AND')
    return unless cond
    if options[:condition]
      [options[:condition]].flatten[0] <<  " #{joiner} #{cond}"
    else
      options[:condition] = cond
    end
  end

  # Returns true if a table exists within the database, false
  # otherwise.

  def table_exists?(table)
    table_info(table) ? true : false
  end
  alias_method :table_exist?, :table_exists?

  private

  def database_does_not_exist_exception?(ex)
    false
  end

  def table_already_exists_exception?(ex)
    false
  end
end

end
