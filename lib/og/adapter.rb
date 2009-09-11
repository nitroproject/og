require "og/store"

module Og

# A specialization of a Store. Typically provides the interface
# to an RDBMS System.
#
# The following adapters are available for the SQL Store:
#
# * Mysql
# * PostgreSQL
# * SQLite3
# * Kirbybase
# * DBI (DataBase Interface)

class Adapter < Store

  # Load the store for the given name.
  #
  # Examples:
  #
  #   Adapter.for_name(:dbi)
  #   Adapter.for_name(:mysql) 
  #   Adapter.for_name(:postgresql)

  def self.for_name name
    info "Og uses the #{name.to_s.capitalize} store."
    name = :postgresql if name.to_s == 'psql'
    require("og/adapter/" + name.to_s)
    return Og.const_get("#{name.to_s.capitalize}Adapter")
  end

end

end
