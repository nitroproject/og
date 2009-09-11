require 'og/relation/refers_to'

module Og

# A 'has_one' relation.
#
# === Examples
#
# user.profile = Profile.new
# user.profile
# user.profile(true) # reload
# user.profile(:reload => true)

class HasOne < RefersTo
end

end
