#--
# Autoload core Og classes as needed. Potentially minimizes
# startup time and memory footprint, allows for cleaner source
# files, and makes it easier to move files around.
#++

if $DBG || defined?(Library)

  require "og/model/timestamped"
  require "og/model/sti"
  require "og/model/unmanageable"
  require "og/model/taggable"

else

  Og::Mixin.autoload :Timestamped, "og/model/timestamped"
  Og::Mixin.autoload :TimestampedOnCreate, "og/model/timestamped"
  Og::Mixin.autoload :SingleTableInherited, "og/model/sti"
  Og::Mixin.autoload :Unmanageable, "og/model/unmanageable"
  Og::Mixin.autoload :Taggable, "og/model/taggable"

end
