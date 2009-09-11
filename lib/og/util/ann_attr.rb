# Customize Facets ann_attr implementation to be more suitable
# for Og.
#--
# FIXME, THINK: why are these defined in Module.
#++

require "facets/annotations"
require "facets/attributes"
require "og/validation"

class Module

  # Hook the ann_attr callback to customize default behaviour

  def attr_callback(target, args, harg)
    return if harg[:serialize] == false
    return unless ann_class = harg[:class]

    if ann_class.respond_to?(:included_as_property)
      ann_class.included_as_property(target, args.dup.push(harg))
    end

    #if !target.serializable_attributes.empty?
    if !Og.unmanageable_classes.include?(target)
      target.is(Og::Model) if !target.ancestors.include?(Og::Model)
      target.is(Og::Mixin::Validation) if !target.ancestors.include?(Og::Mixin::Validation)
    end
  end

  # For backwards compatibility, this is DEPRECATED.

  alias_method :property, :attr_accessor

  # Return the serializable attributes of this class.
  # Serializable are attributes with the class annotation that
  # are not marked as :serializable => false.
  #
  # Examples:
  #
  #   class MyClass
  #     attr_accessor :test
  #     attr_accessor :name, String, :doc => 'Hello'
  #     attr_accessor :age, Fixnum
  #     attr_accessor :body, String, :serialize => false
  #   end
  #
  #   MyClass.instance_attributes # => [:test, :name, :age, :body]
  #   MyClass.serializable_attributes # => [:name, :age]

  def serializable_attributes
    instance_attributes.find_all do |a|
      anno = self.ann(a)
      anno[:class] and (anno[:serialize] != false)
    end
  end

  # Define force methods for the given attribute.
  #--
  # TODO: Remove this method, it is only needed in attributeutils
  # and can be defined there.
  #++

  def define_force_method_for(sym)
    if klass = self.ann(sym, :class)
      code = %{
        def __force_#{sym}(val)}
      if respond_to?(:"force_#{sym}")
        code << %{self.#{sym} = force_#{sym}(val)}
      else
        code << %{
          self.#{sym} = (}
        code << case klass.name
          when Fixnum.name
            'val.to_s.empty? ? nil : val.to_i'
          when String.name
            'val.to_s'
          when Float.name
            'val.to_f'
          when Time.name
            'val.is_a?(Hash) ? Time.local(val["year"],val["month"],val["day"],val["hour"],val["min"]) : Time.parse(val.to_s)'
          when Date.name
            'val.is_a?(Hash) ? Time.local(val["year"],val["month"],val["day"]).to_date : Time.parse(val.to_s).to_date'
          when TrueClass.name, FalseClass.name
            'val == "off" || val == "false" ? false : '\
                                                'val ? true : false'
          else
            'val'
        end
        code << %{)
        end
        }
      end

      module_eval(code)
    end
  end

  #--
  # Define all force methods.
  #++

  def define_force_methods
    for a in serializable_attributes
      define_force_method_for(a)
    end
  end

end
