begin
  require "mysql"
rescue Object => ex
  error "Ruby-Mysql bindings are not installed!"
  error "Trying to use the pure-Ruby binding included in Og"
  begin
    # Attempt to use the included pure ruby version.
    require "og/vendor/mysql"
  rescue Object => ex
    error ex
  end
end

require "og/store/sql"
require "og/adapter/mysql/override"
require "og/adapter/mysql/utils"

module Og

# A Store that persists objects into a MySQL database. To read 
# documentation about the methods, consult the documentation for 
# SqlStore and Store.
#
# Here is some useful code to initialize your MySQL RDBMS for 
# development. You probably want to be more careful with 
# provileges on your production environment.
#
# mysql> GRANT ALL PRIVELEGES 
# ON keystone.*
# TO <$sys_dbuser name>@localhost
# IDENTIFIED BY '(password)'
# WITH GRANT OPTION;

class MysqlAdapter < SqlStore
  include MysqlUtils; extend MysqlUtils

  # Initialize the MySQL store.
  #
  # === Options
  #
  # * :name, the name of the database.
  # * :user, the username for using the database.
  # * :password, the password of the database user.
  # * :address, the addres where the server is listening.
  # * :port, the port where the server is listening.
  # * :socket, is useful when the pure ruby driver is used.
  #    this is the location of mysql.sock. For Ubuntu/Debian 
  #    this is '/var/run/mysqld/mysqld.sock'. You can find
  #    the location for your system in my.cnf

  def initialize(options)
    super

    @typemap.update(TrueClass => 'tinyint', Time => 'datetime')

    @conn = Mysql.connect(
      options[:address] || options[:host] || 'localhost', 
      options[:user],
      options[:password], 
      options[:name],
      options[:port],
      options[:socket]
    )

    # You should set recconect to true to avoid MySQL has
    # gone away errors.

    if @conn.respond_to? :reconnect
      options[:reconnect] = true unless options.has_key?(:reconnect)
      @conn.reconnect = options[:reconnect]
    end

  rescue Object => ex
    if database_does_not_exist_exception? ex
      info "Database '#{options[:name]}' not found!"
      create_db(options)
      retry
    end

    error ex.to_s    
    
    raise
  end

  def close
    @conn.close
    super
  end

  # Create a database.
  
  def create_db(options)
    # gmosx: system is used to avoid shell expansion.
    system 'mysqladmin', '-f', "--user=#{options[:user]}", 
        "--password=#{options[:password]}", 
        "--host=#{options[:address]}",
        "--port=#{options.fetch(:port, 3306)}" ,        
        'create', options[:name]    
    super        
  end

  # Drop a database.
  
  def destroy_db(options)
    system 'mysqladmin', '-f', "--user=#{options[:user]}", 
        "--password=#{options[:password]}",
        "--host=#{options[:address]}",
        "--port=#{options.fetch(:port, 3306)}" ,        
        'drop', options[:name]
    super
  end
  
  # The type used for default primary keys.
  
  def primary_key_type
    "integer(11) unsigned AUTO_INCREMENT PRIMARY KEY"
  end

  def query_statement(sql)
    @conn.query_with_result = true 
    return @conn.query(sql)
  end

  def exec_statement(sql)
    @conn.query_with_result = false
    @conn.query(sql)
  end

  # Perform an sql update, return the number of updated rows.
  
  def sql_update(sql)
    exec(sql)
    @conn.affected_rows
  end

  # Return the last inserted row id.
  
  def last_insert_id(klass = nil) 
    @conn.insert_id
  end
  
  # Start a transaction. The store used is saved in a thread 
  # local variable to force reuse of this store throughout 
  # the transaction.
  
  def start
    Thread.current[:transaction_store] = self

    @transaction_nesting += 1
  
    # nop on myISAM based tables
    exec_statement "START TRANSACTION"
  end

  # Commit a transaction.

  def commit
    @transaction_nesting -= 1

    # nop on myISAM based tables
    exec_statement "COMMIT" if @transaction_nesting < 1
    
    Thread.current[:transaction_store] = nil    
  end

  # Rollback a transaction.

  def rollback
    @transaction_nesting -= 1

    # nop on myISAM based tables
    exec_statement "ROLLBACK" if @transaction_nesting < 1

    Thread.current[:transaction_store] = nil
  end

  def write_attr_boolean(value)
    return value ? "'1'" : "NULL"
  end
  # Returns the MySQL information of a table within the database or
  # nil if it doesn't exist. Mostly for internal usage.

  def table_info(table)
    r = query_statement("SHOW TABLE STATUS FROM #{@options[:name]} LIKE '#{self.class.escape(table.to_s)}'")
    return r && r.blank? ? nil : r.next
  end

private

  def database_does_not_exist_exception?(ex)
    ex.errno == 1049
  end
  
  def table_already_exists_exception?(ex)
    ex.errno == 1050 # table already exists.
  end    
  
end

end
