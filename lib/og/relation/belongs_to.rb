#require 'facets/hash/insert'
 
require 'og/relation/refers_to'

module Og

class BelongsTo < RefersTo

  def enchant
    super
    target_class.ann!(:self)[:descendants] ||= []
    target_class.ann!(:self, :descendants) << [owner_class, foreign_key]
  end
  
end

end
