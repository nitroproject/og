#require 'facets/kernel/constant'
#require 'facets/string/capitalized'

require 'english/inflect'

require 'facets/inheritor'

require 'og/util/inflect'

module Og

# A relation between Entities.
#--
# Relations are resolved in multiple passes. First
# the relations are logged in :relations...
#++

class Relation

  # The parameters of this relation.

  attr_accessor :options

  # A generalized initialize method for all relations.
  # Contains common setup code.

  def initialize(args, options = {})
    @options = options
    @options.update(args.pop) if args.last.is_a?(Hash)

    target_name = if collection
      :target_plural_name
    else
      :target_singular_name
    end

    # Check that all needed options are provided.

    if args.empty? or (not (args.last.is_a?(Class) or args.last.is_a?(Symbol)))
      raise "Class of target not defined"
    end

    # Try to set the target class. Checks for class and
    # class symbol.

    if args.last.to_s.capitalized?
      @options[:target_class] = args.pop
    end

    # Try to set the target name.

    if args.last.is_a? Symbol
      @options[target_name] = args.pop
    end

    # Set the name of the relation.

    options[:name] = options[target_name]

    # Is the relation polymorphic? If so mark the class as
    # polymorphic.

    if polymorphic_marker?
      owner_class = options[:owner_class]
      options[:target_class] = Object
      owner_class.ann(:self, :polymorphic => :parent)
      owner_class.ann(:self, :polymorphic_relation => options[:name])
      owner_class.send(:include, Og::Mixin::Unmanageable)
    end

    # Inflect target_class if not provided.

    @options[:target_class] ||= @options[target_name].to_s.singular.camelize.intern
  end

  # Get an option.

  def [](key)
    @options[key]
  end

  # Set an option.

  def []=(key, val)
    @options[key] = val
  end

  # Is this a polymorphic marker?

  def polymorphic_marker?
    @options[:polymorphic] || (target_class == Object)
  end

  # Is this a polymophic relation? A relation is polymorphic if
  # the target class is a polymophic parent class.

  def polymorphic?
    return false unless target_class.is_a?(Class)
    return target_class.ann(:self, :polymorphic) == :parent
  end

  # Resolve a polymorphic target class.
  # Overrided in subclasses.

  def resolve_polymorphic
  end

  # This method is implemented in subclasses.

  def enchant
  end

  def to_s
    self.class.to_s.underscore
    # @options[:target_name]
  end

  # Access the hash values as methods.

  def method_missing(sym, *args)
    return @options[sym]
  end

end

# A collection of helper methods and resolvers
# for relations.

class Relation
  class << self

  # To avoid forward declarations, references to undefined
  # (at the time of the creation of the relation) classes are
  # stored as symbols. These symbols are resolved by this
  # method.
  #
  # First attempts to find a class in the form:
  #
  # owner_class::class
  # (ie, Article::Category)
  #
  # then a class of the form:
  #
  # class
  # (ie, ::Category)
  #--
  # The lookup is handled automatically by the #constant Facets
  # method.
  #++

  def symbol_to_class(sym, owner_class)
    owner_class = owner_class.to_s

    begin
      c = "#{owner_class}::#{sym}"
      const = constant(c)
      owner_class =~ /^(.*)::(?:[^:])*$/
      owner_class = $1
    end while const.class != Class && !owner_class.empty?

    return const.class == Class ? const : nil
  end
  alias_method :resolve_symbol, :symbol_to_class

  def resolve_targets(klass)
    for r in klass.relations
      next if r.polymorphic_marker?
      if r.target_class.is_a? Symbol
        if klass = symbol_to_class(r.target_class, r.owner_class)
          r.options[:target_class] = klass
        else
          error "Cannot resolve target class '#{r.target_class}' for relation '#{r}' of class '#{r.owner_class}'!"
        end
      end
    end
  end

  # Resolve polymorphic relations. Returns the generated
  # sub-classes.
  #
  # If the target class is polymorphic, create a specialized
  # version of that class (the target) enclosed in the
  # owner namespace.
  #
  # For example:
  #
  #   class Article
  #     has_many :comments
  #     ...
  #   end
  #
  # generates:
  #
  #   class Article::Comment < Comment
  #   end

  def resolve_polymorphic_relations(klass)
    generated = []

    for r in klass.relations
      if r.polymorphic?
        target_dm = r.target_class.demodulize

        # Replace the target class by either creating or getting the
        # polymorphic child if it already exists.

        r[:target_class] = if r.owner_class.constants.include?(target_dm)
          r.owner_class.const_get(target_dm)
        else
          child = Class.new(r.target_class)
          child.ann(:self, :polymorphic => :child)
          # Specialize of the polymorphic relation.
          cr = child.relation(child.ann(:self, :polymorphic_relation))
          cr.options.delete(:polymorphic)
          cr.options.delete(:target_plural_name)
          cr.options.delete(:target_singular_name)
          cr.options[:target_class] = klass
          r.owner_class.const_set(target_dm, child)
        end

        r.resolve_polymorphic

        generated << r[:target_class]
      end
    end

    return generated
  end

  # Resolve the names of the relations.
  #--
  # For the target name it uses the demodulized class name.
  #++

  def resolve_names(klass)
    for r in klass.relations
      target_name = if r.collection
        :target_plural_name
      else
        :target_singular_name
      end

      # Inflect the relation name.

      unless r[target_name]
        r[target_name] = r.target_class.to_s.demodulize.underscore.downcase
        r[target_name].replace r[target_name].plural if r.collection
      end

      r[:name] = r[target_name]
    end
  end

  # General resolve method.

  def resolve(klass, action = :resolve_polymorphic)
    for r in klass.relations
      r.send(action)
    end
  end

  # Perform relation enchanting on this class.

  def enchant(klass)
    # update inherited relations.

    for r in klass.relations
      r[:owner_class] = klass
    end

    # enchant.

    for r in klass.relations
      unless (klass.ann(:self, :polymorphic) == :parent) and r.polymorphic_marker?
        r.enchant()
      end
    end

    klass.each_schema_child do |child|
      #FIXME: Probably the relation classes should be passed a manager when they enchant...
      child.class.__send__(:attr_accessor, :ogmanager)
      child.instance_variable_set('@ogmanager', klass.ogmanager)

      Relation::enchant(child)
    end
  end

  end
end

# Relations domain specific language (DSL). This language
# defines macros that are used to define relations. Additional
# macros allow for relation inspection.

module RelationDSL

  inheritor(:relations, [], :+)

  # RelationDSL class-level methods

  module Self

    # === Examples
    #
    #   belongs_to :article # inflects Article
    #   belongs_to Article  # inflects :article
    #   belongs_to :article, Article
    #   belongs_to :article, Article, :view => 'lala'

    def belongs_to(*args)
      require "og/relation/belongs_to"
      relations! << Og::BelongsTo.new(args, :owner_class => self)
    end

    # === Examples
    #
    #   refers_to :topic # inflects Topic
    #   refers_to Topic # inflects :topic

    def refers_to(*args)
      require "og/relation/refers_to"
      relations! << Og::RefersTo.new(args, :owner_class => self)
    end

    # === Examples
    #
    #   has_one User

    def has_one(*args)
      require "og/relation/has_one"
      relations! << Og::HasOne.new(args, :owner_class => self)
    end

    # === Examples
    #
    #   has_many Comment
    #   has_many :comments, Comment

    def has_many(*args)
      require "og/relation/has_many"
      relations! << Og::HasMany.new(args, :owner_class => self, :collection => true)
    end

    # ..

    def joins_many(*args)
      require "og/relation/joins_many"
      relations! << Og::JoinsMany.new(args, :owner_class => self, :collection => true)
    end

    # ..

    def many_to_many(*args)
      require "og/relation/many_to_many"
      relations! << Og::ManyToMany.new(args, :owner_class => self, :collection => true)
    end

    def inspect_relation(name)
      relations.find { |r| r[:name].to_sym == name.to_sym }
    end

    alias_method :relation, :inspect_relation

  end

end

end
