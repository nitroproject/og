begin
  require "sqlite3"
rescue Object => ex
  error "Ruby-Sqlite3 bindings are not installed!"
  error ex
end

require "fileutils"
require "set"

require "og/store/sql"
require "og/adapter/sqlite/override"
require "og/adapter/sqlite/utils"

module Og

# A Store that persists objects into an Sqlite3 database.
#
# As well as the usual options to the constructor, you can also pass a
# :busy_timeout option which defines how quickly to retry a query, should the
# database be locked. The default value is 50ms. The retry will currently
# continue until successful.
#
# To read documentation about the methods, consult the documentation
# for SqlStore and Store.

class SqliteAdapter < SqlStore
  include SqliteUtils; extend SqliteUtils

  # Initialize the Sqlite store.
  # This store provides a default name.
  
  def initialize(options)
    super
    @busy_timeout = (options[:busy_timeout] || 50)/1000
    @conn = SQLite3::Database.new(db_filename(options))
  end

  def close
    @conn.close
    super
  end

  # Override if needed.

  def db_filename(options)
    if options[:name] == ':memory:' || options[:name] == :memory
      ':memory:'
    else
      "#{options[:name]}.db"
    end
  end

  def destroy_db(options)
    FileUtils.rm_f(db_filename(options))
    super
  end

  # The type used for default primary keys.
  
  def primary_key_type
    'integer PRIMARY KEY'
  end
  
  # SQLite send back a BusyException if the database is locked.
  # Currently we keep sending the query until success or the universe
  # implodes.
  # Note that the SQLite3 ruby library provides a busy_timeout, and
  # busy_handler facility, but I couldn't get the thing to work.

  def query_statement(sql)
    return @conn.query(sql)
  rescue SQLite3::BusyException
    sleep(@busy_timeout)
    retry
  end

  def exec_statement(sql)
    return @conn.query(sql).close
  rescue SQLite3::BusyException
    sleep(@busy_timeout)
    retry
  end
  
  def start
    Thread.current[:transaction_store] = self
    
    @conn.transaction if @transaction_nesting < 1
    @transaction_nesting += 1
  end

  def commit
    @transaction_nesting -= 1
    @conn.commit if @transaction_nesting < 1

    Thread.current[:transaction_store] = nil
  end

  def rollback
    @transaction_nesting -= 1

    @conn.rollback if @transaction_nesting < 1

    Thread.current[:transaction_store] = nil
  end

  def sql_update(sql)
    exec(sql)
    @conn.changes
  end

  def last_insert_id(klass = nil)
    query("SELECT last_insert_rowid()").first_value.to_i
  end

  # Returns the Sqlite information of a table within the database or
  # nil if it doesn't exist. Mostly for internal usage.

  def table_info(table)
    r = query_statement("SELECT name FROM sqlite_master WHERE type='table' AND name='#{self.class.escape(table.to_s)}'");
    return r && r.blank? ? nil : r.next
  end

private

  # gmosx: any idea how to better test this?

  def table_already_exists_exception?(ex)
    ex.to_s =~ /table .* already exists/i
  end    

end

end
