require 'og/relation/joins_many'

module Og

# A 'many_to_many' relation.
# This objects is associated with an other using an intermediate 
# join table. Just an alias for 'joins_many'.
#
# === Examples
#
#   many_to_many Category
#   many_to_many :categories, Category

class ManyToMany < JoinsMany
  #--
  # FIXME: better enchant polymorphic parents and then add 
  # an alias to :objects.
  #++
  
  def resolve_polymorphic
    target_class.module_eval <<-EOS, __FILE__, __LINE__
      many_to_many :#{owner_class.to_s.demodulize.underscore.pluralize}
    EOS
  end
end

end
