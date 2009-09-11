begin
  require "postgres"
rescue Object => ex
  error "Ruby-PostgreSQL bindings are not installed!"
  error ex
end

require "og/store/sql"
require "og/adapter/postgresql/override"
require "og/adapter/postgresql/utils"

module Og

# A Store that persists objects into a PostgreSQL database.
# To read documentation about the methods, consult the 
# documentation for SqlStore and Store.
#
# This is the reference Og store.

class PostgresqlAdapter < SqlStore
  extend PostgresqlUtils; include PostgresqlUtils

  def initialize(options)
    super
  
    @typemap.update(Og::Blob => "bytea")

    @conn = PGconn.connect(
      options[:address] || options[:host], 
      options[:port], 
      "--client_min_messages=WARNING", nil, 
      options[:name], 
      options[:user].to_s, 
      options[:password].to_s
    )
    schema_order = options[:schema_order]
    encoding = options[:encoding]
    min_messages = options[:min_messages]
    
    @conn.exec("SET search_path TO #{schema_order}") if schema_order
    @conn.exec("SET client_encoding TO '#{encoding}'") if encoding
    @conn.exec("SET client_min_messages TO '#{min_messages}'") if min_messages
  rescue PGError => ex
    if database_does_not_exist_exception? ex
      info "Database '#{options[:name]}' not found!"
      create_db(options)
      retry
    end
    raise
  end

  def create_db(options)
    # gmosx: system is used to avoid shell expansion.
    system "createdb", options[:name], "-U", options[:user], "-q"
    super
  end

  def destroy_db(options)
    system "dropdb", options[:name], "-U", options[:user], "-q"
    super
  end

  # The type used for default primary keys.
  
  def primary_key_type
    "serial PRIMARY KEY"
  end
  
  def enchant(klass, manager)
    super

    pk = klass.primary_key
    
    seq = "#{klass::OGTABLE}_#{pk}_seq"
    
    pkann = klass.ann(pk)
    
    unless pkann[:sequence]
      if pkann[:sql] =~ /SERIAL/i
        klass.ann(pk, {:sequence => seq})
      else
        klass.ann(pk, {:sequence => false})
      end
    end
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

    sql << ") WITHOUT OIDS"

    begin
      exec(sql, false)
      info "Created table '#{klass.table}'."
    rescue Object => ex
      if table_already_exists_exception? ex
        # Don't return yet. Fall trough to also check for the 
        # join table.
      else
        handle_sql_exception(ex, sql)
      end
    end
  end

  def query_statement(sql)
    return @conn.exec(sql)
  end

  def exec_statement(sql)
    @conn.exec(sql).clear
  end

  def sql_update(sql)
    debug(sql) if $DBG  
    res = @conn.exec(sql)
    changed = res.cmdtuples
    res.clear
    return changed
  end

  # Return the last inserted row id.
  
  def last_insert_id(klass)
    seq = klass.ann(klass.primary_key, :sequence)
    
    res = query("SELECT currval('#{seq}')")
    lid = Integer(res.first_value)
    
    return lid
  end
  
  # The insert sql statements.
  
  def insert(klass, inserts)
    next_oid = nil
    
    if !inserts[klass.primary_key] || inserts[klass.primary_key] == "NULL"
      if seq = klass.ann(klass.primary_key, :sequence)
        next_oid = Integer(query("SELECT nextval('#{seq}')").first_value)
        inserts[klass.primary_key] = write_attr(next_oid, :class => Integer)
      end
    end
    super
    
    return next_oid
  end
  
  # :section: Transaction methods.

  # Start a new transaction. The store used is saved in a thread 
  # local variable to force reuse of this store throughout 
  # the transaction.
  
  def start
    Thread.current[:transaction_store] = self
    
    # neumann: works with earlier PSQL databases too.
    exec('BEGIN TRANSACTION') if @transaction_nesting < 1
    
    if @transaction_nesting >= 1 && @conn.server_version > 80000
      exec("SAVEPOINT SP#{@transaction_nesting}")
    end
    
    @transaction_nesting += 1
  end
  
  # Commit a transaction.

  def commit
    @transaction_nesting -= 1
    exec('COMMIT') if @transaction_nesting < 1
    
    if @transaction_nesting >= 1 && @conn.server_version > 80000
      exec("RELEASE SAVEPOINT SP#{@transaction_nesting}")
    end
    
    Thread.current[:transaction_store] = nil
  end

  # Rollback a transaction.

  def rollback
    @transaction_nesting -= 1
    exec('ROLLBACK') if @transaction_nesting < 1
    
    if @transaction_nesting >= 1 && @conn.server_version > 80000
      exec("ROLLBACK TO SAVEPOINT SP#{@transaction_nesting}")
    end

    Thread.current[:transaction_store] = nil
  end
  
#  def read_attr(s, anno, col)
#    store = self.class
#    {
#      String    => nil,
#      Integer   => :parse_int,
#      Float     => :parse_float,
#      Time      => :parse_timestamp,
#      Date      => :parse_date,
#      TrueClass => :parse_boolean,
#      Og::Blob  => :parse_blob
#    }.each do |klass, meth|
#      if anno[:class].ancestor? klass
#        return meth ? 
#          "#{store}.#{meth}(res[#{col} + offset])" : "res[#{col} + offset]"
#      end
#    end
#
#    # else try to load it via YAML
#    "YAML::load(res[#{col} + offset])"
#  end

  def read_row(obj, res, res_row, row)
    res.fields.each_with_index do |field, idx|
      obj.instance_variable_set "@#{field}", res.getvalue(row, idx)
    end
  end

  # Returns the PostgreSQL information of a table within the database or
  # nil if it doesn't exist. Mostly for internal usage.

  def table_info(table)
    r = query_statement("SELECT c.* FROM pg_catalog.pg_class c LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace WHERE c.relkind = 'r' AND n.nspname NOT IN ('pg_catalog', 'pg_toast') AND pg_catalog.pg_table_is_visible(c.oid) AND c.relname = '#{self.class.escape(table.to_s)}'")
    return r && r.blank? ? nil : r.next
  end

private

  def database_does_not_exist_exception?(ex)
    ex.message =~ /database .* does not exist/i
  end
  
  def table_already_exists_exception?(ex)
    ex.message =~ /already exists/
  end    
  
end

end

