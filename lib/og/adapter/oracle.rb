require 'oci8'

require 'og/store/sql'
require 'og/adapter/oracle/override'
require 'og/adapter/oracle/utils'

module Og

# The Oracle adapter. This adapter communicates with 
# an Oracle rdbms. For extra documentation see 
# lib/og/adapter.rb
#
# Connects to Oracle by config[:user], config[:password], config[:database],
# config[:privilege]. If you need DBA privilege, please set privilege as
# :SYSDBA or :SYSOPER.

class OracleAdapter < SqlStore
  extend OracleUtils; include OracleUtils
  
  def initialize(config)
    super
    
    @typemap.update(
      Integer => 'number',
      Fixnum => 'number',
      String => 'varchar2(1024)', # max might be 4000 (Oracle 8)
      TrueClass => 'char(1)',
      Numeric => 'number',
      Object => 'varchar2(1024)',
      Array => 'varchar2(1024)',
      Hash => 'varchar2(1024)',
      Time => 'TIMESTAMP',
      Date => 'DATE',
      DateTime => 'TIMESTAMP'
    )
    
    # TODO: how to pass address etc?
    @conn = OCI8.new(
      config[:user],
      config[:password],
      config[:name], 
      config[:privilege]
    )

    # gmosx: does this work?
    @conn.autocommit = true
  rescue OCIException => ex
    #---
    # mcb:
      # Oracle will raise a ORA-01017 if username, password, or 
    # SID aren't valid. I verified this for all three.
    # irb(main):002:0> conn = Oracle.new('keebler', 'dfdfd', 'kbsid')
    # /usr/local/lib/ruby/site_ruby/1.8/oracle.rb:27:in `logon': ORA-01017:
    # invalid username/password; logon denied (OCIError)
    #+++
    if database_does_not_exist_exception? ex
      Logger.info "Database '#{options[:name]}' not found!"
      create_db(options)
      retry
    end
    raise
  end
  
  def close
    @conn.logoff
    super
  end
  
  #--
  # mcb:
  # Unlike MySQL or Postgres, Oracle database/schema creation is a big deal. 
  # I don't know how to do it from the command line. I use Oracle's Database 
  # Configuration Assistant utility (dbca). I takes 30min - 1hr to create 
  # a full blown schema. So, your FIXME comments are fine. I'm thinking you
  # won't be able to do this via Og, but once created, Og will be able to 
  # create tables, indexes, and other objects.
  #++

  def create_db(database, user = nil, password = nil)
    # FIXME: what is appropriate for oracle?
    # `createdb #{database} -U #{user}`
    super
    raise NotImplementedError, "Oracle Database/Schema creation n/a"
  end

  def drop_db(database, user = nil, password = nil)
    # FIXME: what is appropriate for oracle?
    # `dropdb #{database} -U #{user}`
    super
    raise NotImplementedError, "Oracle Database/Schema dropping n/a"
  end
  
  # The type used for default primary keys.
  
  def primary_key_type
    'integer PRIMARY KEY'
  end
  
  def enchant(klass, manager)
    pk = klass.primary_key
    
    seq = if klass.schema_inheritance_child?
      "#{table(klass.schema_inheritance_root_class)}_#{pk}_seq"
    else
      "#{table(klass)}_#{pk}_seq"
    end
    
    pkann = klass.ann(pk)
    
    pkann[:sequence] = OracleUtils.shorten_string(seq) unless pkann[:sequence] == false
    
    super
  end

  def query_statement(sql)
    @conn.exec(sql)
  end

  def exec_statement(sql)
    Logger.debug "ORACLE "+sql
    @conn.exec(sql)
  end

  def sql_update(sql)
    Logger.debug sql if $DBG  
    res = @conn.exec(sql)
    return res.to_i
  end

  # Return the last inserted row id.
  
  def last_insert_id(klass)
    seq = klass.ann(klass.primary_key, :sequence)
    
    res = query_statement("SELECT #{seq}.nextval FROM DUAL")
    lid = Integer(res.first_value)
    res.close
    
    return lid
  end
  
  # The insert sql statements.
  
  def insert_sql(sql, klass)
    str = ''
    
    if klass.ann(klass.primary_key, :sequence)
      str << "@#{klass.primary_key} = store.last_insert_id(#{klass})\n"
    end
    
    str << "store.exec \"#{sql}\""
    
    return str
  end
  
  # :section: Transaction methods.

  # Start a new transaction.

  def start  
    @conn.autocommit = false
    
    @transaction_nesting += 1
  end
  
  # Commit a transaction.
  
  def commit
    @transaction_nesting -= 1
    @conn.commit if @transaction_nesting < 1
  ensure
    @conn.autocommit = true
  end

  # Rollback a transaction.

  def rollback
    @transaction_nesting -= 1
    @conn.rollbackif @transaction_nesting < 1
  ensure
    @conn.autocommit = true
  end
  
  # :section: Misc methods.
  
  # Create the SQL table where instances of the given class
  # will be serialized.
  
  def create_table(klass)
    fields = fields_for_class(klass)
    
    # Oracle hard limit
    OracleUtils.shorten_table_name(klass) if klass.table.size > 30
    raise "ORACLE TOO LONG! #{klass.table.size}" if klass.table.size > 30

    sql = "CREATE TABLE #{klass.table} (#{fields.join(', ')}"

    # Create table constraints.

    if constraints = klass.ann(:self, :sql_constraint)
      sql << ", #{constraints.join(', ')}"
    end

    sql << ")"

    begin
      exec(sql, false)
      Logger.info "Created table '#{klass.table}'."
    rescue Object => ex
      if table_already_exists_exception? ex
        # Don't return yet. Fall trough to also check for the 
        # join table.
      else
        handle_sql_exception(ex, sql)
      end
    end
    
    seq = klass.ann[klass.primary_key][:sequence]
    # Create the sequence for this table. 
    begin
      exec_statement("CREATE SEQUENCE #{seq} INCREMENT BY 1 START WITH 1 NOMAXVALUE NOMINVALUE NOCYCLE")
      Logger.info "Created sequence '#{seq}'."       
    rescue OCIError => ex
      if table_already_exists_exception?(ex)
        Logger.debug "Sequence #{seq} already exists" if $DBG
      else
        raise
      end
    end
    
  end # end create_table
  
  def drop_table(klass)
    super
    
    seq = klass.ann[klass.primary_key][:sequence]
    # Create the sequence for this table. 
    begin
      exec_statement("DROP SEQUENCE #{seq}")
      Logger.info "Dropped sequence '#{seq}'."       
    rescue OCIError => ex
      if sequence_does_not_exist_exception?(ex)
        Logger.debug "Sequence #{seq} didn't exist" if $DBG
      else
        raise
      end
    end
    
  end
  
  def resolve_limit_options(options, sql)
    from = options[:offset] || 1
    to = from + options[:limit] if options[:limit]
    sql.replace "SELECT * FROM (#{sql}) WHERE ROWNUM "
    if to && from
      sql << "BETWEEN #{from} AND #{to}"
    elsif to
      sql << "<= #{options[:limit]}"
    elsif from
      sql << ">= #{from}"
    end
  end
  
  def read_attr(s, a, col)
    store = self.class
    {
      String    => nil,
      Integer   => :parse_int,
      Float     => :parse_float,
      Time      => :parse_timestamp,
      Date      => :parse_date,
      TrueClass => :parse_boolean,
      Og::Blob  => :parse_blob
    }.each do |klass, meth|
      if a.class.ancestor? klass
        return meth ? 
          "#{store}.#{meth}(res[#{col} + offset])" : "res[#{col} + offset]"
      end
    end

    # else try to load it via YAML
    "YAML::load(res[#{col} + offset])"
  end
  
  
private

  def database_does_not_exist_exception?(ex)
    raise ex unless ex.kind_of?(OCIException)
    ex.message =~ /ORA-01017/i
  end

  def table_already_exists_exception?(ex)
    raise ex unless ex.kind_of?(OCIException)
    ex.message =~ /ORA-00955/i
  end
  
  def sequence_does_not_exist_exception?(ex)
    raise ex unless ex.kind_of?(OCIException)
    ex.message =~ /ORA-02289/i
  end

end

end
