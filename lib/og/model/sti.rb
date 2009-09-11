module Og::Mixin

# This module denotes that the base class follows the
# SingleTableInheritance pattern. Ie, all the subclasses of the
# base class are stored in the same schema (table).
#
# This mixin is only useful in SQL based Og stores.
#
# For more details, read this article:
# http://www.martinfowler.com/eaaCatalog/singleTableInheritance.html
#
# Example:
#
#   class User
#     is SingleTableInherited
#     ..
#   end
#
#   class AdminUser < User
#     ..
#   end
#
# Both User and AdminUser are serialized to the same SQL table.
#--
# TODO: rename some old schema_inheritance_xxx names in the
# source.
#++

module SingleTableInherited

  def self.included(base)
    # This class is the root class in a single table inheritance
    # chain. So inject a special class ogtype field that holds
    # the class name.

    base.attr_accessor :ogtype, String, :sql => "VARCHAR(50)"
  end

  # SingleTableInherited class-level methods.

  module Self

    def table_class
      klass = self
      until !Og.manager.manageable?(klass) or klass.schema_inheritance_root?
        klass = klass.superclass
      end
      return klass
    end

    def og_allocate(res, row = 0)
      begin
        Object.constant(res["ogtype"]).allocate
      rescue TypeError => e
        # FIXME: use res['ogtype'] here, this is slow!
        # But res['ogtype'] isn't implemented in -pr and some mysql exts,
        # create compat layer
        ogmanager.with_store do |s|
          col = create_field_map(self)[:ogtype]
        end

        Object.constant(res[col]).allocate
      ensure
        res.close if res.respond_to?(:close)
        ogmanager.put_store
      end
    end

    def each_schema_child
      return unless schema_inheritance_root?
      self.descendents.each do |child|
        yield child
      end
    end

    def schema_options
      if schema_inheritance_child?
        {:type => self}
      else
        {}
      end
    end

    def schema_inheritance?
      true
    end

    def schema_inheritance_child?
      superclass.respond_to?(:schema_inheritance?)
    end

    def schema_inheritance_root?
      (!superclass.respond_to?(:schema_inheritance?))
    end
  end

end

end
