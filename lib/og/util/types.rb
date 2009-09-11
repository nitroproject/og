module Og

# Some useful type macros to help when defining properties.
# You can easily code your own type macros. Just return the 
# array that should be passed to the attr_xxx macros.
#
# Examples:
#
#   attr_accessor :name, VarChar(30)

def self.VarChar(size)
  return String, :sql_type => "VARCHAR(#{size})"
end

NotNull = { :null => false }

Null = { :null => true }

Char = { :sql_type => "CHAR(1)" }

end
