require "uuidtools"
require "og/model/uuid/encode22"

module Og::Mixin

# Include this mixin to your model to use a UUID as a primary key.
# It generates a value that should be unique across multiple 
# computers. This is useful for database replication and also 
# when you may need to merge data from one database into another. 
# If you're using auto incremental values there'll be duplicate 
# records in each database, but using a unique value such as this 
# means the primary key from both databases should be unique.
#
# Example:
#   class Article
#     include UUIDPrimaryKey
#     attr_acessor :title, :body
#   end
#  
# Related articles:
# * http://www.mysqlperformanceblog.com/2007/03/13/to-uuid-or-not-to-uuid/
# * http://tools.assembla.com/breakout/wiki/FreeSoftware
# * http://joshua.schachter.org/2007/01/autoincrement.html

module UUIDPrimaryKey

  # Add an UUID key attribute.

  attr_accessor :oid, String, :sql => "CHAR(22) PRIMARY KEY"

  # The SQL type of the primary key.  

  def primary_key_type
    "CHAR(22)"
  end
  
  # Create the primary key before inserting the object. Respects
  # an already set primary key (useful for inter-db synchronization)

  def create_primary_key
    @oid ||= UUID.timestamp_create().to_s22
  end

end

end
