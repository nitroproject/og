# * Matt Bowen  <matt.bowen@farweststeel.com>
# * George Moschovitis  <gm@navel.gr>
# (c) 2004-2005 Navel, all rights reserved.
# $Id: oracle.rb 266 2005-02-28 14:50:48Z gmosx $

require 'oracle'

require 'og/store/sql'
#require 'og/adapter/oracle/override'
#require 'og/adapter/oracle/utils'

module Og

# The Oracle adapter. This adapter communicates with 
# an Oracle rdbms. For extra documentation see 
# lib/og/adapter.rb

class OracleAdapter < SqlStore

  def initialize
    super
    
    @typemap.update(
      Integer => 'number',
      Fixnum => 'number',
      String => 'varchar2(1024)', # max might be 4000 (Oracle 8)
      TrueClass => 'char(1)',
      Numeric => 'number',
      Object => 'varchar2(1024)',
      Array => 'varchar2(1024)',
      Hash => 'varchar2(1024)'
    )
    
    # TODO: how to pass address etc?
    @store = Oracle.new(config[:user], config[:password], config[:database])
    # gmosx: better use this???
    # @store = Oracle.new(config[:tns])

    # gmosx: does this work?
    @store.autocommit = true
  rescue Exception => ex
    # mcb:
      # Oracle will raise a ORA-01017 if username, password, or 
    # SID aren't valid. I verified this for all three.
    # irb(main):002:0> conn = Oracle.new('keebler', 'dfdfd', 'kbsid')
    # /usr/local/lib/ruby/site_ruby/1.8/oracle.rb:27:in `logon': ORA-01017: invalid username/password; logon denied (OCIError)
    if database_does_not_exist_exception? ex
      Logger.info "Database '#{options[:name]}' not found!"
      create_db(options)
      retry
    end
    raise
  end
  
  def close
    @store.logoff
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
    
    pkann = klass.ann[pk]
    
    pkann[:sequence] = seq unless pkann[:sequence] == false
    
    super
  end

  def query_statement(sql)
    return @conn.exec(sql)
  end

  def exec_statement(sql)
    @conn.exec(sql).clear
  end

  def sql_update(sql)
    Logger.debug sql if $DBG  
    res = @conn.exec(sql)
    changed = res.cmdtuples
    res.clear
    return changed
  end

  # Return the last inserted row id.
  
  def last_insert_id(klass)
    seq = klass.ann[klass.primary_key][:sequence]
    
    res = query_statement("SELECT #{seq}.nextval FROM DUAL")
    lid = Integer(res.first_value)
    res.close
    
    return lid
  end
  
  # The insert sql statements.
  
  def insert_sql(sql, klass)
    str = ''
    
    if klass.ann[klass.primary_key][:sequence]
      str << "@#{klass.primary_key} = store.last_insert_id(#{klass})\n"
    end
    
    str << "store.exec \"#{sql}\""
    
    return str
  end
  
  # :section: Transaction methods.

  # Start a new transaction.

  def start  
    @store.autocommit = false
    
    @transaction_nesting += 1
  end
  
  # Commit a transaction.
  
  def commit
    @transaction_nesting -= 1
    @store.commit if @transaction_nesting < 1
  ensure
    @store.autocommit = true
  end

  # Rollback a transaction.

  def rollback
    @transaction_nesting -= 1
    @store.rollbackif @transaction_nesting < 1
  ensure
    @store.autocommit = true
  end
  
  
  def create_table(klass)
    super
    
    seq = klass.ann[klass.primary_key][:sequence]
    # Create the sequence for this table. 
    begin
      exec_statement("CREATE SEQUENCE #{seq}")
      Logger.info "Created sequence '#{seq}'."       
    rescue Exception => ex
      # gmosx: any idea how to better test this?
      if table_already_exists_exception?(ex)
        Logger.debug "Sequence #{seq} already exists" if $DBG
      else
        raise
      end
    end
    
  end
  
  def drop_table(klass)
    super
    exec_statement("DROP SEQUENCE #{klass.ann[klass.primary_key][:sequence]}")
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
  
=begin
  def calc_field_index(klass, db)
    # gmosx: This is incredible!!! argh!
    # res = db.query "SELECT * FROM #{klass::DBTABLE} # LIMIT 1"
    res = db.query "SELECT * FROM (SELECT * FROM #{klass::DBTABLE}) WHERE ROWNUM <= 1"
    meta = db.managed_classes[klass]

    columns = res.getColNames

    for idx in (0...columns.size)
      # mcb: Oracle will return column names in uppercase.
      meta.field_index[columns[idx].downcase] = idx
    end

  ensure
    res.close if res
  end

  def eval_og_oid(klass)
    klass.class_eval %{
      prop_accessor :oid, Fixnum, :sql => "number PRIMARY KEY"
    }
  end

  def create_table(klass, db)
    conn = db.get_connection

    fields = create_fields(klass)

    sql = "CREATE TABLE #{klass::DBTABLE} (#{fields.join(', ')}"
    
    # Create table constrains.
    
    if klass.__meta and constrains = klass.__meta[:sql_constrain]
      sql << ", #{constrains.join(', ')}"
    end

    # mcb: Oracle driver chokes on semicolon.
    sql << ")"

    # mcb:
    # Oracle driver appears to have problems executing multiple SQL 
    # statements in single exec() call. Chokes with or without semicolon 
    # delimiter. Solution: make separate calls for each statement.

    begin
      conn.store.exec(sql).close
      Logger.info "Created table '#{klass::DBTABLE}'."
      
      # Create indices.

      if klass.__meta and indices = klass.__meta[:sql_index]
        for data in indices
          idx, options = *data
          idx = idx.to_s
          pre_sql, post_sql = options[:pre], options[:post]
          idxname = idx.gsub(/ /, "").gsub(/,/, "_").gsub(/\(.*\)/, "")
          sql = " CREATE #{pre_sql} INDEX #{klass::DBTABLE}_#{idxname}_idx #{post_sql} ON #{klass::DBTABLE} (#{idx})"  
          conn.store.exec(sql).close
          Logger.info "Created index '#{klass::DBTABLE}_#{idxname}_idx'."          
        end
      end
    rescue Exception => ex
      # gmosx: any idea how to better test this?
      if table_already_exists_exception?(ex)
        Logger.debug 'Table or index already exists' if $DBG
        return
      else
        raise
      end
    end

    # Create the sequence for this table. 
    begin
      conn.store.exec("CREATE SEQUENCE #{klass::DBSEQ}").close
      Logger.info "Created sequence '#{klass::DBSEQ}'."       
    rescue Exception => ex
      # gmosx: any idea how to better test this?
      if table_already_exists_exception?(ex)
        Logger.debug "Sequence already exists" if $DBG
      else
        raise
      end
    end

    # Create join tables if needed. Join tables are used in
    # 'many_to_many' relations.
    
    if klass.__meta and joins = klass.__meta[:sql_join] 
      for data in joins
        # the class to join to and some options.
        join_class, options = *data
        
        # gmosx: dont use DBTABLE here, perhaps the join class
        # is not managed yet.
        join_table = "#{self.class.join_table(klass, join_class)}"
        join_src = "#{self.class.encode(klass)}_oid"
        join_dst = "#{self.class.encode(join_class)}_oid"
        begin
          conn.store.exec("CREATE TABLE #{join_table} ( key1 integer NOT NULL, key2 integer NOT NULL )").close
          conn.store.exec("CREATE INDEX #{join_table}_key1_idx ON #{join_table} (key1)").close
          conn.store.exec("CREATE INDEX #{join_table}_key2_idx ON #{join_table} (key2)").close
        rescue Exception => ex
          # gmosx: any idea how to better test this?
          if table_already_exists_exception?(ex)
            Logger.debug "Join table already exists" if $DBG
          else
            raise
          end
        end
      end
    end

  ensure
    db.put_connection
  end

  def drop_table(klass)
    super
    exec "DROP SEQUENCE #{klass::DBSEQ}"    
  end

  # Generate the property for oid.

  #--
  # mcb:
  # Oracle doesn't have a "serial" datatype. Replace with 
  # integer (which is probably just a synonym for NUMBER(38,0))
  # A sequence is created automatically by Og.
  #++

  def eval_og_oid(klass)
    klass.class_eval %{
      prop_accessor :oid, Fixnum, :sql => 'integer PRIMARY KEY'
    }
  end
=end
private

  def database_does_not_exist_exception?(ex)
    ex.message =~ /ORA-01017/i
  end

  def table_already_exists_exception?(ex)
    ex.message =~ /ORA-00955/i
  end

end

=begin
# The Oracle connection.

class OracleConnection < Connection

  # mcb:
  # The database connection details are tucked away in a 
  # TNS entry (Transparent Network Substrate) which specifies host, 
  # port, protocol, and database instance. Here is a sample TNS 
  # entry:
  #
  # File: tns_names.ora
  #
  # KBSID =
  #  (DESCRIPTION =
  #    (ADDRESS_LIST =
  #      (ADDRESS = (PROTOCOL = TCP)(HOST = keebler.farweststeel.com)(PORT = 1521))
  #    )
  #    (CONNECT_DATA =
  #      (SID = KBSID)
  #    )
  #  )

  def initialize(db)
    super
    config = db.config

    begin
      # FIXME: how to pass address etc?
      @store = Oracle.new(config[:user], config[:password], config[:database])
      # gmosx: better use this???
      # @store = Oracle.new(config[:tns])

      # gmosx: does this work?
      @store.autocommit = true
    rescue Exception => ex
      # mcb:
        # Oracle will raise a ORA-01017 if username, password, or 
      # SID aren't valid. I verified this for all three.
      # irb(main):002:0> conn = Oracle.new('keebler', 'dfdfd', 'kbsid')
      # /usr/local/lib/ruby/site_ruby/1.8/oracle.rb:27:in `logon': ORA-01017: invalid username/password; logon denied (OCIError)
      # gmosx:
      # any idea how to better test this? an integer error id?
      if ex.to_s =~ /ORA-01017/i     
        Logger.info "Database '#{config[:database]}' not found!"
        @db.adapter.create_db(config[:database], config[:user])
        retry
      end
      raise
    end
  end

  def close
    @store.logoff
    super
  end

  def query(sql)
    Logger.debug sql if $DBG
    begin
      return @store.exec(sql)
    rescue Exception => ex
      Logger.error "DB error #{ex}, [#{sql}]"
      Logger.error ex.backtrace.join("\n")
      raise
#      return nil
    end
  end

  def exec(sql)
    Logger.debug sql if $DBG
    begin
      @store.exec(sql)
    rescue Exception => ex
      Logger.error "DB error #{ex}, [#{sql}]"
      Logger.error ex.backtrace.join("\n")
      raise
    end
  end

  def start
    @store.autocommit = false
  end
  
  def commit
    @store.commit
  ensure
    @store.autocommit = true
  end
  
  def rollback
    @store.rollback
  ensure
    @store.autocommit = true
  end

  def valid_res?(res)
    return !(res.nil?)
  end

  def read_one(res, klass)
    return nil unless valid_res?(res)

    row = res.fetch
    return nil unless row

    obj = klass.new
    obj.og_read(row)

    res.close
    return obj
  end

  def read_all(res, klass)
    return [] unless valid_res?(res)
    objects = []

    while row = res.fetch
      obj = klass.new
      obj.og_read(row)
      objects << obj
    end

    res.close
    return objects
  end

  def read_int(res, idx = 0)
    val = res.fetch[idx].to_i
    res.close
    return val
  end

end

=end

end

