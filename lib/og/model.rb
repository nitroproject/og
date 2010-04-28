#require "facets/kernel/assign_with"

require "og/relation"
require "og/ez/clause"
require "og/ez/condition"

module Og

# = Og::Model
#
# Include this module to classes to make them managable by Og.
#
# == Explanation
#
# In everyday use, you probably won't have a class without an attribute to
# store in the database.  So all you have to do is put your attributes first.
# Having to include this module is much more likely to be used in modules you
# plan on mixing into other classes.
#
# == Examples Of Use
#
# ==== This is what should normally be used
#
#   class Identity
#     attr_accessor :identities, Arrray
#     belongs_to :user, User
#   end
#
# A class which does not start with an attribute will error out because
# Og::Model has not been included yet.
#
# ==== This will not work
#
#   class Identity
#     belongs_to :user, User # THIS WILL NOT WORK BECAUSE Og::Model IS NOT INCLUDED YET
#     attr_accessor :identities, Array # This line does include Og::Model but it's too late
#   end
#
# ==== This will work
#
#   class Identity
#     is Og::Model
#     belongs_to :user, User
#     attr_accessor :identities, Array
#   end
#
# "has_one", "has_many", "many_to_many" and "belong_to" would require this.
#
module Model

  is Anise #::Attribute
  is RelationDSL

  # Persist the object. This is a wrapper method around
  # Store#save.
  #
  # Save an object to store. Insert if this is a new object or
  # update if this is already inserted in the database.
  #
  # Checks if the object is valid before saving. Throws a
  # ValidationError if the object is invalid and populates
  # obj.validation_errors.
  #--
  # FIXME: should throw exception (on validation errors or
  # any errors)
  #++

  def save(options = nil)
    self.class.ogmanager.with_store do |s|
      s.save(self, options)
    end
  end
  alias_method :save!, :save
  alias_method :validate_and_save, :save

  #--
  # gmosx: wtf is this?
  #++

  def self.model_from_string(str)
    res = nil
    Manager.managed_classes.each do |klass|
      if klass.name == str
        res = klass
        break
      end
    end
    res
  end

  # Force saving of the objects, even if the validations
  # don't pass.

  def force_save!(options = nil)
    self.class.ogmanager.with_store do |s|
      s.force_save!(self, options)
    end
  end

  # Insert the object in the store.

  def insert
    self.class.ogmanager.with_store do |s|
      self.og_insert(s)
      # s.insert(self)
    end
  end

  # Update an existing object in the store.

  def update(options = nil)
    self.class.ogmanager.with_store do |s|
      s.update(self, options)
    end
  end

  # Update only specific attributes.

  def update_attributes(*attrs)
    self.class.ogmanager.with_store do |s|
      s.update(self, :only => attrs)
    end
  end
  alias_method :update_attribute, :update_attributes
  alias_method :aupdate, :update_attributes

  # Update using a custom sql query.

  def update_by_sql(set)
    self.class.ogmanager.with_store do |s|
      s.update_by_sql(self, set)
    end
  end
  alias_method :update_sql, :update_by_sql
  alias_method :supdate, :update_by_sql

  # Set attributes (update + save).
  #
  # Examples:
  #   a = Article[oid]
  #   a.set_attributes :accepted => true, :update_time => Time.now
  #   a.set_attribute :accepted => true
  #--
  # gmosx, THINK: maybe make this the default behaviour of
  # update_attributes?
  #++

  def set_attributes(attrs = {})
    for a, val in attrs
      instance_variable_set "@#{a}", val
    end
    update_attributes(*attrs.keys)
  end
  alias_method :set_attribute, :set_attributes

  # Set attribute (like instance_variable_set)
  #
  # Example:
  #
  #   a = Article[oid]
  #   a.instance_attribute_set :accepted, true

  def instance_attribute_set(a, val)
    instance_variable_set "@#{a}", val
    update_attribute(a.to_sym)
  end

  # Reload this model instance from the store.

  def reload
    self.class.ogmanager.with_store do |s|
      s.reload(self, self.pk)
    end
  end
  alias_method :reload!, :reload

  # Delete this model instance from the store.

  def delete(cascade = true)
    self.class.ogmanager.with_store do |s|
      s.delete(self, self.class, cascade)
    end
  end
  alias_method :delete!, :delete

  # Execute the block in a transaction.

  def transaction(&block)
    self.class.ogmanager.with_store do |s|
      s.transaction(&block)
    end
  end

  def transaction_raise(&block)
    self.class.ogmanager.with_store do |s|
      s.transaction_raise(&block)
    end
  end

  # Is this object saved in the store?

  def saved?
    not @oid.nil?
  end
  alias_method :serialized?, :saved?

  # Assign the attributes of this object from the given hash
  # of values.
  #--
  # TODO: This was using AttributeUtils.populate_object, but the
  # definition for it has gone missing. I simply put Facets' #assign 
  # in it's place. I have no idea what the +options+ might be or do.
  #++
  def assign_attributes(values, options = {})
    #AttributeUtils.populate_object(self, values, options)
    assign(values)
    return self
  end
  #alias_method :assign, :assign_attributes

  # Save all building collections. Transparently called
  # when saving an object, allows efficient object relationship
  # setup.
  #
  # Example:
  #
  #   a = Article.new
  #   a.categories << c1
  #   a.categories << c2
  #   a.tags << t1
  #   a.tags << t2
  #   a.save
  #--
  # TODO: at the moment, this only handles collection relations.
  # Should handle belongs_to/refers_to as well.
  #++

  def save_building_collections(options = nil)
    if @pending_building_collections
      for rel in self.class.relations
        next unless rel.class.ann(:self, :collection)
        collection = send(rel.name.to_s)
        collection.save_building_members
      end
      @pending_building_collections = false
    end
  end

  # Quote the given object.

  def og_quote(obj)
    self.class.ogmanager.with_store do |s|
      s.quote(obj)
    end
  end

  # Model class-level methods

  module Self

    # :section: Utility methods.

    # Return a singular name for this Model class.

    def singular_name
      to_s.gsub(/::/, "_").underscore
    end

    # Return a plural name for this Model class.

    def plural_name
      singular_name.pluralize
    end

    # :section: Creation methods.

    # Initialize and save an instance in one step.

    def create(*args)
      obj = self.new(*args)
      yield(obj) if block_given?
      obj.insert
      return obj
    end

    # An alternative creation helper, does _not_ call the
    # initialize method when there are mandatory elements.

    def create_with(hash)
      obj = nil
      arity = self.method(:initialize).arity

      if arity > 0 || arity < -1
        obj = self.allocate
      else
        obj = self.new
      end

      #obj.instance_assign(hash)
      obj.populate(hash)

      ogmanager.with_store do |s|
        s.save(obj)
      end

      return obj
    end

    # Create a new instance of this class and assign the given
    # values.

    def assign_attributes(values, options = {})
      AttributeUtils.populate_object(self.new, values, options)
    end
    alias_method :assign, :assign_attributes

    # :section: Load/Save methods.

    # Load an instance of this class using the primary
    # key. If the class defines a text key, this string key
    # may optionally be used!

    def load(pk)
      # gmosx: leave the checks in this order (optimized)
      #if (key = ann(:self, :text_key)) && pk.to_i == 0 && (pk !~ /\S{22}/)
      #  # A string is passed as pk, try to use it as a
      #  # text key too.
      #  puts("find_by_#{key}  == #{pk}")
      #  send("find_by_#{key}", pk)
      #else
        # A valid pk is always > 0
        ogmanager.with_store do |s|
          s.load(pk, self)
        end
      #end
    end
    alias_method :[], :load
    alias_method :exist?, :load

    # Update the representation of this class in the
    # store.

    def update(set, options = nil)
      ogmanager.with_store do |s|
        s.update_by_sql(self, set, options)
      end
    end

    # :section: Query methods.

    # Find a specific instance of this class according
    # to the given conditions.
    #
    # Unlike the lower level store.find method it accepts
    # Strings and Arrays instead of an option hash.
    #
    # Examples:
    #
    #   User.find :condition => "name LIKE 'g%'", :order => 'name ASC'
    #   User.find :where => "name LIKE 'g%'", :order => 'name ASC'
    #   User.find :sql => "WHERE name LIKE 'g%' ORDER BY name ASC"
    #   User.find :condition => [ 'name LIKE ?', 'g%' ], :order => 'name ASC', :limit => 10
    #   User.find "name LIKE 'g%'"
    #   User.find "WHERE name LIKE 'g%' LIMIT 10"
    #   User.find [ 'name LIKE ?', 'g%' ]

    def find(options = {}, &block)
      options = resolve_non_hash_options(options)

      ez_resolve_options(options, &block) if block_given?

      if find_options = self.ann(:self, :find_options)
        options = find_options.dup.update(options)
      end

      options[:class] = self
      options.merge! schema_options

      ogmanager.with_store do |s|
        s.find(options)
      end
    end
    alias_method :all, :find

    # Find a single instance of this class.

    def find_one(options = {}, &block)
      options = resolve_non_hash_options(options)

      ez_resolve_options(options, &block) if block_given?

      if find_options = self.ann(:self, :find_options)
        options = find_options.dup.update(options)
      end

      options[:class] = self
      options.merge! schema_options

      ogmanager.with_store do |s|
        s.find_one(options)
      end
    end
    alias_method :one, :find_one
    alias_method :first, :find_one

    # Select an object using an sql query.

    def select(sql, options = {})
      ogmanager.with_store do |s|
        s.select(sql, self, options)
      end
    end

    # Select one instance using an sql query.

    def select_one(sql, options = {})
      ogmanager.with_store do |s|
        s.select_one(sql, self, options)
      end
    end

    # Query the database for an model that matches the example.
    # The example is a hash populated with the property values
    # to search for.
    #
    # The provided attribute values are joined with AND to build
    # the actual query.
    #
    # Examples:
    #
    #   Article.query_by_example :title => "IBM%", :hits => 2
    #   Article.find_with_properties :title => "IBM%", :hits => 2
    #
    #--
    # FIXME: replace the "--" hack with something more sensible.
    #++

    def query_by_example(example)
      condition = []
      example.each do |k, v|
        next if (v.nil? or v == "--")
        if v.is_a? String and v =~ /%/
          condition << "#{k} LIKE #{Og.quote(v)}"
        else
          condition << "#{k} = #{Og.quote(v)}"
        end
      end

      condition = condition.join(' AND ')

      options = {
        :condition => condition,
        :class => self,
      }

      options.merge! schema_options

      ogmanager.with_store do |s|
        s.find(options)
      end
    end
    alias_method :qbe, :query_by_example
    alias_method :find_with_attributes, :query_by_example

    # :section: Aggregations / Calculations

    # Perform a general aggregation/calculation.

    def aggregate(term, options = {})
      options[:class] = self
      ogmanager.with_store do |s|
        s.calculate(term, options)
      end
    end
    alias_method :calculate, :aggregate

    # Perform a count query.

    def count(options = {})
      options[:field] = "*"
      calculate("COUNT(*)", options).to_i
    end

    # Find the minimum of a property.
    # Pass a :group option to return an aggregation.

    def minimum(min, options = {})
      options[:field] = min
      calculate("MIN(#{min})", options)
    end
    alias_method :min, :minimum

    # Find the maximum of a property.
    # Pass a :group option to return an aggregation.

    def maximum(max, options = {})
      options[:field] = max
      calculate("MAX(#{max})", options)
    end
    alias_method :max, :maximum

    # Find the average of a property.
    # Pass a :group option to return an aggregation.

    def average(avg, options = {})
      options[:field] = avg
      calculate("AVG(#{avg})", options)
    end
    alias_method :avg, :average

    # Find the sum of a property.
    # Pass a :group option to return an aggregation.

    def summarize(sum, options = {})
      options[:field] = sum
      calculate("SUM(#{sum})", options)
    end
    alias_method :sum, :summarize

    # :section: Delete/Destroy methods.

    # Delete an instance of this Model class using the actual
    # instance or the primary key.

    def delete(obj_or_pk, cascade = true)
      ogmanager.with_store do |s|
        s.delete(obj_or_pk, self, cascade)
      end
    end
    alias_method :delete!, :delete

    # Delete all objects of this Model class.
    #--
    # TODO: add cascade option.
    #++

    def delete_all
      ogmanager.with_store do |s|
        s.delete_all(self)
      end
    end

    def destroy
      ogmanager.with_store do |s|
        s.send(:destroy, self)
      end
    end

    def escape(str)
      ogmanager.with_store do |s|
        s.escape(str)
      end
    end

    def transaction(&block)
      ogmanager.with_store do |s|
        s.transaction(&block)
      end
    end

    def transaction_raise(&block)
      ogmanager.with_store do |s|
        s.transaction_raise(&block)
      end
    end

    # Return the primary key for this class. Search the
    # serializable attributes, try to find one annotated as
    # primary_key. The default primary key is oid.

    def primary_key
      return @__primary_key if @__primary_key

      for a in serializable_attributes
        if ann(a, :primary_key)
          @__primary_key = a
          break
        end
      end

      @__primary_key ||= :oid
    end

    # Set the default find options for this model.

    def set_find_options(options)
      ann :self, :find_options => options
    end
    alias_method :find_options, :set_find_options

    # Enable schema inheritance for this Model class.
    # The Single Table Inheritance pattern is used.

    def set_schema_inheritance
      include Og::SchemaInheritanceBase
    end
    alias_method :schema_inheritance, :set_schema_inheritance

    def schema_options
      {}
    end

    def schema_inheritance?
      false
    end

    def schema_inheritance_child?
      false
    end

    def schema_inheritance_root?
      false
    end

    def each_schema_child
      return
    end

    #---
    #jdl: This is the beginnings of using inheritence rules to simplify STI
    #+++

    def table_class
      self
    end

    #--
    # farms/rp: is there not another way to access the root class?
    #++

    def schema_inheritance_root_class
      return table_class
    end

    # Set the default order option for this model.

    def set_order(order_str)
      unless ann(:self, :find_options)
        ann(:self, :find_options => { :order => order_str })
      else
        ann!(:self, :find_options).update(:order => order_str)
      end
    end

#def order(order_str)
#  set_order(order_str)
#end

    alias_method :order, :set_order
    alias_method :order_by, :set_order

    # Set a custom table name.

    def set_sql_table(table)
      ann :self, :sql_table => table.to_s
    end
    alias_method :set_table, :set_sql_table

    # Set the primary key.

    def set_primary_key(pk, pkclass = Fixnum)
      self.ann(pk, :primary_key => true)
      #     self.ann!(pk)[:class] ||= pkclass # gmosx, WHAT is this?
    end

    # Is this model a polymorphic parent?

    def polymorphic_parent?
      self.to_s == self.ann(:self, :polymorphic).to_s
    end

    # Used internally to fix the forward reference problem.

    def const_missing(sym) # :nodoc: all
      return sym
    end

    # Returns an array of all relations formed by other og managed
    # classes with the class of this object.
    #
    # This is needed by the PostgreSQL foreign key constraints
    # system.

    def resolve_remote_relations
      klass = self
      manager = klass.ogmanager
      relations = Array.new
      manager.managed_classes.each do |managed_class|
        next if managed_class == klass
        managed_class.relations.each do |rel|
          relations << rel if rel.target_class == klass
        end
      end
      relations
    end

    # Define a scope for the following og method invocations
    # on this managed class. The scope options are stored
    # in a thread variable.
    #
    # At the moment the scope is only considered in find
    # queries.

    def set_scope(options)
      Thread.current["#{self}_OG_SCOPE"] = options
    end

    # Get the scope.

    def get_scope
      Thread.current["#{self}_OG_SCOPE"]
    end

    # Execute some Og methods in a scope.

    def with_scope(options)
      set_scope(options)
      yield
      set_scope(nil)
    end

    # Handles dynamic finders.
    #
    # Examples:
    #
    #   class User
    #     attr_accessor :name, String
    #     attr_accessor :age, Fixnum
    #   end
    #
    #   User.find_by_name('gmosx')
    #   User.find_by_name_and_age('gmosx', 3)
    #   User.find_all_by_name_and_age('gmosx', 3)
    #   User.find_all_by_name_and_age('gmosx', 3, :name_op => 'LIKE', :age_op => '>', :limit => 4)
    #   User.find_or_create_by_name_and_age('gmosx', 3)

    def method_missing(sym, *args, &block)
      if match = /find_(all_by|by)_([_a-zA-Z]\w*)/.match(sym.to_s)
        return find_by_(match, args, &block)
      elsif match = /find_or_create_by_([_a-zA-Z]\w*)/.match(sym.to_s)
        return find_or_create_by_(match, args, &block)
      else
        super
      end
    end

    def find_by_(match, args, &block)
      finder(match, args, &block)
    end

    def find_or_create_by_(match, args, &block)
      obj = finder(match, args)

      unless obj
        attrs = match.captures.last.split('_and_')
        obj = self.create do |obj|
          attrs.zip(args).map do |name, value|
            obj.instance_variable_set "@#{name}", value
          end
        end
        yield(obj) if block_given?
      end

      return obj
    end

    private

    # Resolve String/Array options.
    #--
    # FIXME: move to sql store?
    #++

    def resolve_non_hash_options(options)
      if options.is_a? String
        if options =~ /^WHERE/i
          # pass the string as sql.
          return { :sql => options }
        else
          # pass the string as a condition.
          return { :condition => options }
        end
      elsif options.is_a? Array
        # pass the array as condition (prepared statement style
        # parsing/quoting.
        return { :condition => options }
      end

      return options
    end

    # Resolve ez options, ie options provided using the
    # Ruby query language.
    #--
    # gmosx: investigate this.
    #++

    def ez_resolve_options(options, &block)
      klass = self.name.downcase.to_sym
      # conditions on self first
      # conditions = [ez_condition(:outer => outer_mapping[klass], :inner => inner_mapping[klass])]
      conditions = [ez_condition()]

      # options[:include].uniq.each do |assoc|
      #   conditions << reflect_on_association(assoc).klass.ez_condition(:outer => outer_mapping[assoc], :inner => inner_mapping[assoc])
      # end

      yield *conditions

      condition = Caboose::EZ::Condition.new
      conditions.each { |c| condition << c }
      options[:condition] = condition.to_sql
    end

    # Returns a Condition for this object.

    def ez_condition(options = {}, &block)
      options[:table_name] ||= table()
      Caboose::EZ::Condition.new(options, &block)
    end

    # Helper method for dynamic finders. Finds the object dynamically parsed
    # method name is after.

    def finder(match, args)
      finder = (match.captures.first == "all_by" ? :find : :find_one)

      attrs = match.captures.last.split("_and_")

      options = (ann(:find_options) || {}).dup
      options = args.pop if args.last.is_a?(Hash)

      relations_map = {}
      relations.each {|r| relations_map[r.name.to_s] = r }

      ret = nil
      ogmanager.with_store do |store|

        condition = attrs.zip(args).map do |name, value|
          if relation = relations_map[name]
            field_name = relation.foreign_key
            value = value.send(relation.target_class.primary_key)
            value = store.quote(value)

          elsif name =~ /^(#{relations_map.keys.join('|')})_(.*)$/
            r = relations_map[$1]
            tc = r.target_class
            if tc.serializable_attributes.include?($2.to_sym)
              field_name = r.foreign_key
              value = "(SELECT #{tc.primary_key} FROM #{tc::OGTABLE} WHERE #{$2} = '#{value}')"
            end
          else
            anno = ann(name.to_sym)
            field_name = anno[:field] || anno[:name] || name.to_sym
            value = store.quote(value)
          end

          options["#{name}_op".to_sym] ||= "IN" if value.is_a?(Array)

          %|#{field_name} #{options.delete("#{name}_op".to_sym) || '='} #{value}|
        end.join(" AND ")

        options.merge!(
          :class => self,
          :condition => condition
        )

        ret = store.send(finder, options)
      end
      return ret
    end
  end

end

end
