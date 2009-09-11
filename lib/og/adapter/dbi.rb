begin
  require "dbi"
  require "dbi/trace" if $DBG
rescue Object => ex
  error "Ruby-DBI bindings are not installed!"
  error ex
end

require "og/store/sql"
require "og/adapter/dbi/override"
require "og/adapter/dbi/utils"

# TODO: Move some of this documentation to Oxyliquit (?)

module Og

# A Store that persists objects into one of 13 possible database 
# backends.  The database used is specified by the Og#connect 
# option, +:dbi_driver+.
# To read documentation about the methods available via the dbi 
# adapter, consult the documentation for SqlStore and Store.
# The :dbi_driver option is required by +Og#start+ or its alias
# +Og#run+, +Og#connect+ and +Og#startup+.  
# See below for a list of the database drivers that are supported
# by the DBI package.
# If :adapter => 'dbi' is passed as an option in 
# +Og#connect(options)+, then you must
# also set the +:dbi_driver+ option.  
# The reverse does not hold, you can just set the +:dbi_driver+ 
# option and +:adapter=>'dbi'+ will be set behind the scene. 
# The DBI home {page}[http://ruby-dbi.rubyforge.org/] lists  
# (as at 08/2007), thirteen (13) drivers it can interface to it.
# *PLEASE NOTE:* Before you can use DBI as an OG adapter you 
# *_must_* install a driver for the database you wish to access 
# through DBI.  DBI does *not* install the data base driver.... 
# DBI provides an consistant interface to several drivers -
# _you_ need to ensure the desired database driver is on your 
# system.
# Assuming you have the neccessary driver(s) installed, DBI can 
# interface with:
#  * ADO (ActiveX Data Objects)
#  * DB2
#  * Frontbase
#  * InterBase
#  * mSQL
#  * MySQL
#  * ODBC
#  * Oracle
#  * OCI8 (Oracle)
#  * PostgreSQL
#  * Proxy/Server
#  * SQLite
#  * SQLRelay
#
# === Resources:
# Currently there is no gem to install DBI, so installation is  
# quite manual and involves some configuration.  
# See the Oxyliquit tip here... TODO.
# A useful guide that covers driver installation is available 
# {here}[http://rubyurl.com/zXI], an articles on using DBI are
# {here}[http://rubyurl.com/VgR], and {here}[http://rubyurl.com/Qrr]
# ==== DBI setup
# The following database driver parameters can be set when using 
# the DBI apdater:
# +dbi+ +dbd_proxy+ +dbd_sybase+ +dbd_sqlite+ +dbd_mysql+ 
# +dbd_frontbase+ +dbd_pg+ +dbd_db2+ +dbd_oracle+ +dbd_odbc+ 
# +dbd_ado+ +dbd_msql+ +dbd_interbase+ +dbd_sqlrelay+
#
# - Install unixODBC (or iODBC) using your distro's packages.
# - Install ruby-odbc (see the README file 
#   {here}[http://ch-werner.de/rubyodbc/] for instructions)
# - Install your vendors' ruby drivers 
# - Configure then install DBI.  
#

  class DbiAdapter < SqlStore

#The data source name (DSN) identifies the type of connection that
#DBI should make. 
#The other two required arguments are the username and password 
#of your database account.
#The DSN always begins with DBI or dbi.  The DSN can be given in 
#any of the following formats:
# DBI:dbi_driver
# DBI:dbi_driver:db_name:host_name
# DBI:dbi_driver:param=val;param=val
#The +param=val+ admit driver-specific parameters, which means 
#that drivers can be extensible in the connection parameters 
#they accept
#=== Defaults:
# TODO: MySQL, PostgreSQL, Oracle, etc.
#+database=test+
#+host=localhost+
#
#=== MySQL parameters (defaults)
#The host where the MySQL server runs
#host=host_name('localhost')
#The database name
#database=db_name('test')
#The TCP/IP port number, for non-localhost connections
#port=port_num
#The pathname of the Unix socket file, for localhost connections
#socket=path_name
#Flags to enable
#flag=num
#Disable or enable compression in the client/server protocol. 
#The default is not to use it (0).
#+mysql_compression={0|1}+
#Use +mysql_client_found_rows=1+ to tell the server to return a 
#count of the rows matched by an statement, regardless of whether 
#they were changed.  +mysql_client_found_rows=0+ to return the 
#count only of rows that are _changed_.
#+mysql_client_found_rows={0|1}+
#Read options from option files, as described in the MySQL 
#Reference Manual
#+mysql_read_default_file=_file_name_+
#Read options from the +[group_name]+ option group (and from the 
#+[client]+ group, if group_name differs from client)
#+mysql_read_default_group=_group_name_+
#
#=== Example
#The minimum required parameters:
#mysql_opts={:dbi_driver=>'mysql', :name => 'valued_data', 
#            :user => 'myself', :password => 'mysecret'}
#
#A more customized example:
#mysql_opts={:dbi_driver=>'mysql', :user => 'myself', 
#            :password => 'mysecret', :name => 'precious_data', 
#            :db_options => { :host => '10.12.11.9', 
#            :mysql_client_found_rows=1 } }

  def initialize( options )
      super
    begin

     # TODO: If absent, provide default user, password, name and 
     # host for drivers such as MySQL, PostgreSQL, Oracle, etc.
     
     # Derived from Kansas
    if options[:dbi_driver]
        dbd      =  options[:dbi_driver] || :sqlite
        options[:dbi_driver] =  dbd 
        dbname   =  options[:name] ||":memory" # Note: The trailing ":" for memory is appended when dsn is created
        options[:name] = dbname 
        options[:user] ||= ""
        options[:password] ||= ""
        db_opt   =  options[:db_options] ? options[:db_options] : {} 
        host     =  db_opt[:host] ||""
        db_opt[:host] = host
        
        dsn = "dbi:" + dbd.to_s.capitalize + ":" + dbname.to_s + ":" + host.to_s
    
    else
        # DBI requires a database driver is specified.
        # raise Exception
        # "The dbi_driver was not used as an option."
    end

    @conn = DBI.connect( dsn, options[:user], options[:password] ) if dsn
     
     # In case $DBG is True:
     # Statement handles created from @conn from this point on 
     # are given the same trace setting. Levels: 0 (off), 1, 2, 3

     options[:dbi_trace_level] ||= 2 if $DBG
     options[:dbi_trace_dest] ||= $stderr if $DBG
    @conn.trace( options[:dbi_trace_level], options[:dbi_trace_dest] ) if $DBG

# TODO: Activate the following when exception handling and create_db is implemented. 
#   rescue DBI::DatabaseError => ex
#    if database_does_not_exist_exception? ex
#      info "Database '#{options[:name]}' not found!"
#      create_db(options)
#      retry
#    end
#    raise
    
   rescue DBI::DatabaseError => e
      puts "A DBI error occurred"
      puts "DBI Error code: #{e.err}"
      puts "DBI Error message: #{e.errstr}"
      puts "DBI Error SQLSTATE: #{e.state}"
     raise
   rescue Exception => e 
      puts "Error code: #{e.err}"
      puts "Error message: #{e.errstr}"
   ensure
      # THINK: What?
   end
    
  end # initialize

  def disconnect
    begin
      @conn.disconnect
    rescue DBI::DatabaseError => e
      puts "A DBI error occurred"
      puts "DBI Error code: #{e.err}"
      puts "DBI Error message: #{e.errstr}"
      puts "DBI Error SQLSTATE: #{e.state}"
     raise 
    rescue Exception => e 
      puts "Error code: #{e.err}"
      puts "Error message: #{e.errstr}"
    ensure
      # super # currently no superclass (SqlStore) disconnect method
    end # begin/rescue/ensure
    
  end # disconnect
  
end # DbiAdapter
  
end # Og



