module Og::Mixin

# Marker module. If included in a class, the Og automanager
# ignores this class.

module Unmanageable
  def self.included(base)
    Og.unmanageable_classes << base
  end
end

end
