require "facets/inheritor"

module Og
module Mixin

# Encapsulates a validation error.
#
# Typical usage:
#   def save
#     obj = Article.assign(request)
#     obj.save
#   rescue ValidationError => ex
#     p ex.errors
#   end

class ValidationError < StandardError

  attr_accessor :object

  def initialize(object)
    @object = object
  end

  def validation_errors
    @object.validation_errors
  end
  alias_method :errors, :validation_errors

  def to_s
    arr = []

    for a, err in errors
      arr << "#{a}: #{err}"
    end

    return arr.join(", ")
  end

  def to_a
    errors.to_a
  end

end

# Add validation support to models.

module Validation

  # The validation errors.

  attr_accessor :validation_errors

  # The validation rules for the base class.

  inheritor(:validation_rules, [], :+)

  # Validation class-level methods.

  module Self

    # Validate that the given attributes have values.
    #
    # Arguments:
    #
    # * a collection of attribute symbols
    # * an optional hash with configuration:
    #   * msg = the error message
    #   * on = if set to :insert only validates on insert
    #
    # Example:
    #
    #   class User
    #     attr_accessor :name, String
    #     validate_value :name, :msg => "Name required"
    #     validate_value :name, :on => :insert
    #   end

    def validate_value(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      msg = options.fetch(:msg, "No value")
      on_insert = options.fetch(:on, false) == :insert

      for a in args
        validation_rules! << lambda do
          next if self.saved? if on_insert
          value = instance_variable_get("@#{a}")
          if value.nil? or (value.respond_to?(:empty?) and value.empty?)
            @validation_errors[a] ||= []
            @validation_errors[a] << msg
          end
        end
      end
    end

    # Validates the confirmation of +String+ attributes.
    #
    # Arguments:
    #
    # * a collection of attribute symbols
    # * an optional hash with configuration:
    #   * msg = the error message
    #   * on = if set to :insert only validates on insert
    #
    # Example:
    #
    #   class User
    #     attr_accessor :password, String
    #     validate_confirmation :password, :msg => "Confirmation doesn't match the password"
    #   end

    def validate_confirmation(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      msg = options.fetch(:msg, "confirmation failed")
      on_insert = options.fetch(:on, false) == :insert

      for a in args
        validation_rules! << lambda do
          next if self.saved? if on_insert
          value = instance_variable_get("@#{a}")
          confirmation = instance_variable_get("@#{a}_confirmation")

          unless value == confirmation
            @validation_errors[a] ||= []
            @validation_errors[a] << msg
          end
        end
      end
    end

    # Validate the length of the given String attributes.
    #
    # Arguments:
    #
    # * a collection of attribute symbols
    # * an optional hash with configuration:
    #   * min = the minimum length
    #   * max = the maximum length
    #   * msg = the error message
    #   * on = if set to :insert only validates on insert
    #
    # Example:
    #
    #   class User
    #     attr_accessor :name, String
    #     validate_value :name, :msg => "Name required"
    #   end

    def validate_length(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      raise "No min or max given" unless ((min = options[:min]) or (max = options[:max]))
      msg = options.fetch(:msg, "No value")
      on_insert = options.fetch(:on, false) == :insert

      for a in args
        validation_rules! << lambda do
          next if self.saved? if on_insert
          if val = instance_variable_get("@#{a}")
            @validation_errors[a] ||= []
            if min
              @validation_errors[a] << msg if val.size < min
            end
            if max
              @validation_errors[a] << msg if val.size > max
            end
          end
        end
      end
    end

    # Validate the format of the given String attributes.
    #
    # Arguments:
    #
    # * a collection of attribute symbols
    # * an optional hash with configuration:
    #   * format = a regular expression describing the valid format
    #   * msg = the error message
    #   * on = if set to :insert only validates on insert
    #
    # Example:
    #
    #   class User
    #     attr_accessor :name, String
    #     validate_value :name, :msg => "Name required"
    #   end

    def validate_format(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      raise "No format given" unless format = options[:format]
      msg = options.fetch(:msg, "No value")
      on_insert = options.fetch(:on, false) == :insert

      for a in args
        validation_rules! << lambda do
          next if self.saved? if on_insert
          if val = instance_variable_get("@#{a}")
            @validation_errors[a] ||= []
            @validation_errors[a] << msg if val.to_s !~ format
          end
        end
      end
    end

    # Validates that the given field(s) contain unique values.
    # Ensures that if a record is found with a matching value,
    # that it is the same record, allowing updates.
    #
    # The Og libraries are required for this method to
    # work. You can override this method if you want to
    # use another OR mapping library.
    #
    # Example:
    #
    #   validate_unique :param, :msg => 'Value is already in use'
    #--
    # TODO: :unique should implicitly generate validate_unique.
    #++

    def validate_unique(*args)
      Validation.add_validation(validation_rules!, "Not unique", *args) do |obj, field|
        value = obj.__send__(field) || ""
        if value.nil? or (value.respond_to? :empty? and value.empty?)
          true
        else
          others = obj.class.send("find_all_by_#{field}".to_sym, value)
          if others.nil? or others.empty?
            true
          else
            if obj.saved?
              others[0] == obj and others.size == 1
            else
              false
            end
          end
        end
      end
    end

    # Validate that a property relation is not nil.
    # This works for all relations.
    #
    # You should not put a validation in both related
    # classes, because it can cause infinite looping.
    #
    # The Og libraries are required for this method to
    # work. You can override this method if you want to
    # use another OR mapping library.
    #
    # Example:
    #
    #   class Uncle
    #     has_many :secrets, Secret
    #     validate_related :secrets
    #   end
    #
    #   class Secret
    #     belongs_to :uncle, Uncle
    #   end

    def validate_related(*args)
      Validation.add_validation(validation_rules!, "Null relation", *args) do |obj, field|
        relations = obj.send(field).load_members
        relations.length == 0 or relations.inject(true) do |memo, relation|
          memo and !relation.nil? and relation.valid?
        end
      end
    end
    alias_method :validate_associated, :validate_related

  end

  # Does the model validate? Some (costly) validations are
  # only checked on insert.

  def validates?
    @validation_errors = Hash.new # { |h,k| h[k] = [] }

    for rule in self.class.validation_rules
      instance_eval(&rule)
    end

    return @validation_errors.empty?
  end
  alias_method :valid?, :validates?

  #--
  # Helper method.
  #++

  def self.add_validation(rules, default_msg, *args, &block)
    options = args.last.is_a?(Hash) ? args.pop : {}
    msg = options.fetch(:msg, default_msg)
    on_insert = options.fetch(:on, false) == :insert

    for a in args
      rules << lambda do
        next if self.saved? and on_insert
        if not block.call(self, a)
          @validation_errors[a] << msg
        end
      end
    end
  end

end

end
end



__END__

class Test
  is Validation

  attr_accessor :name
  validate_value :name
end

t = Test.new
p t.validates?
p t.validation_errors
t.name = "George"
p t.validates?
p t.validation_errors





OLD CODE, please convert!!!
also convert code from facets/validations.rb


require "facets/validation"

# Extend the Validation methods defined in facets/validation.rb
# with extra db related options.

module Validation

  # Encapsulates a list of validation errors.

  class Errors
    setting :invalid_relation, :default => "Undefined"
    setting :not_unique, :default => "The value is already used"
  end

  module Self  # module ClasssMethods

    # Validate that a property relation is not nil.
    # This works for all relations.
    #
    # You should not put a validation in both related
    # classes, because it can cause infinite looping.
    #
    # The Og libraries are required for this method to
    # work. You can override this method if you want to
    # use another OR mapping library.
    #
    # === Example
    #
    # class Uncle
    #   has_many :secrets, Secret
    #   validate_related :secrets
    # end
    #
    # class Secret
    #   belongs_to :uncle, Uncle
    # end

    def validate_related(*params)
      c = parse_config(params,
        :msg => ::Validation::Errors.invalid_relation,
        :on => :save
      )

      params.each do |field|
        define_validation(:related, field, c[:on]) do |obj|
          value = obj.send(field)
          if value.members.length == 0
            obj.errors.add(field, c[:msg])
          else
            valid = value.members.inject do |memo, rel_obj|
              (rel_obj.nil? or rel_obj.valid?) and memo
            end
            obj.errors.add(field, c[:msg]) unless valid
          end
        end
      end
    end

    alias_method :validate_associated, :validate_related

  end

end

end
