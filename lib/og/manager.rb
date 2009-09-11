require "facets/pool"
#require "facets/class/descendents"

require "og/model"
require "og/store"
require "og/adapter"

module Og

# A Manager manages Models. Each Manager is attched to a
# single Store. Multiple Managers can exist in the same Og
# application.

class Manager

  # The name of this manager. Useful in the multiple managers
  # scenario.

  attr_accessor :name

  # The configuration options.

  attr_accessor :options

  # The store used for persistence. This is a virtual field
  # when running in thread_safe mode.

  attr_accessor :store

  # The collection of Models (managed classes) managed by
  # this manager.

  attr_accessor :models

  # The managed object cache. This cache is optional. When
  # used it improves object lookups.

  attr_accessor :cache

  # Initialize the manager.
  #
  # === Options
  #
  # :store, :adapter = the adapter/store to use as backend.

  def initialize(options)
    @options = options
    @name = options[:name]
    @models = []

    @store_class = Adapter.for_name(options[:adapter] || options[:store])
    @store_class.allocate.destroy_db(options) if Og.destroy_schema || options[:destroy]

    initialize_store()
  end

  # Initialize a store.

  def initialize_store
    if @pool
      close_store
    end

    if Og.thread_safe
      @pool = Pool.new
      ( @options[:connection_count] || 5 ).times do
        @pool << @store_class.new(@options)
        @pool.last.ogmanager = self
      end
    else
      @store = @store_class.new(@options)
      @store.ogmanager = self
    end
  end
  alias_method :init_store, :initialize_store

  # Used when changing thread_safe mode

  def close_store
    unless @pool
      @store.close
    else
      @pool.each { |s| s.close }
      @pool.clear
    end
    @pool = nil
  end

  # Get a store from the pool. The pool is thread safe and
  # blocks if it is empty.

  def get_store
    if Thread.current[:transaction_store]
      Thread.current[:transaction_store]
    elsif @pool
      @pool.pop
    else
      @store
    end
  end
  alias_method :store, :get_store

  # Return a store to the pool.

  def put_store(store)
    if Thread.current[:transaction_store]
      # do nothing, transaction still in progress
    elsif @pool and store
      @pool.push(store)
    end
  end

  # Safely work with (multithreaded) stores.

  def with_store
    store = get_store
    raise "BUG: no available store" unless store
    return yield(store)
  ensure
    put_store(store)
  end

  # Resolve polymorphic relations.

  def resolve_polymorphic(klass)
    Relations.resolve_polymorphic(klass)
  end

  # Manage a class. Injects Og related functionality to the
  # class.

  def manage(klass)
    return if managed?(klass) || !manageable?(klass)

    # Check if the class has a :text key.

    for a in klass.serializable_attributes
      if klass.ann(a, :key)
        klass.ann(:self, :text_key => a)
        break
      end
    end

    # DON'T DO THIS!!!
    #--
    # gmosx: this is used though, dont remove without recoding
    # some stuff.
    #++

    klass.module_eval %{
      def ==(other)
        other.instance_of?(#{klass}) ? @#{klass.primary_key} == other.#{klass.primary_key} : false
      end
    }

    klass.class.attr_accessor :ogmanager
    klass.instance_variable_set "@ogmanager", self

    # FIXME: move somewhere else.

    klass.define_force_methods

    Relation.enchant(klass)

    # ensure that the superclass is managed before the
    # subclass.

    manage(klass.superclass) if manageable?(klass.superclass)

    # Perform store related enchanting.

    with_store do |s|
      s.enchant(klass, self)
    end

    # Call special class enchanting code.

    klass.enchant if klass.respond_to?(:enchant)
    @models.push(klass).uniq!
  end

  # Is this class manageable by Og?
  #
  # Unmanageable classes include classes:
  # * without serializable attributes
  # * explicitly marked as Unmanageable (is Og::Unamanageable)
  # * are polymorphic_parents (ie thay are used to spawn polymorphic relations)

  def manageable?(klass)
    klass.respond_to?(:serializable_attributes) &&
      !Og.unmanageable_classes.include?(klass) &&
      !klass.serializable_attributes.empty?
=begin
     and
    (!klass.polymorphic_parent?)
=end
  end

  # Is the class managed by Og?

  def managed?(klass)
    @models.include?(klass)
  end

  # Returns an array containing all classes managed by this manager.

  def managed_classes
    @models
  end

  # Use Ruby's advanced reflection features to find
  # all manageable classes. Managable are all classes that
  # define Properties.

  def manageable_classes
    classes = []

    ObjectSpace.each_object(Class) do |c|
      if defined?(Blow)
        next if c <= Blow::Atom::Node
      end
      if manageable?(c)
        classes << c
      end
    end

    return classes
  end

  # Manage a collection of classes.

  def manage_classes(*classes)
    classes.flatten!
    classes.compact!

    if classes.empty?
      mc = self.class.managed_classes

      classes = manageable_classes.flatten
      classes = classes.reject { |c| mc.member?(c) || !manageable?(c) }
    end

    classes.each { |c| Relation.resolve_targets(c) }

    # The polymorpic resolution step creates more manageable classes.
    classes += classes.map { |c| Relation.resolve_polymorphic_relations(c) }

    classes.flatten!

#    classes = classes.reject { |c| !c or self.class.managed?(c) }

    sc = @store_class.allocate

    if Og.use_uuid_primary_keys
      begin
        require "og/model/uuid"
      rescue LoadError
        error "Please install the uuidtools gem"
      end
      classes.each { |c| c.include UUIDPrimaryKey }
    else
      sc = @store_class.allocate
      classes.each { |c| sc.force_primary_key(c) }
    end

    classes.each { |c| Relation.resolve_targets(c) }
    classes.each { |c| Relation.resolve_names(c) }

    debug "Og manageable classes: #{classes.inspect}" if $DBG

    classes.each { |c| manage(c) }
  end
  alias_method :manage_class, :manage_classes

  # Do not manage the given classes.

  def unmanage_classes(*classes)
    classes = manageable_classes.flatten if classes.empty?

    for c in classes
      @models.delete(c)
    end
  end
  alias_method :unmanage_class, :unmanage_classes

  # Allows functionality that requires a store is finalized
  # to be implemented. A vastly superior method of constructing
  # foreign key constraints is an example of functionality
  # this provides. Currently only used by the PostgreSQL store.
  # Another good use for this would be an alternate table
  # and field creation routine, which could be much faster,
  # something I intend to do to the PostgreSQL store if nobody
  # has reasons for objecting.

  def post_setup
    with_store do |s|
      s.post_setup if s.respond_to?(:post_setup)
    end
  end

  # Helper.

  def <<(sql)
    self.with_store do |s|
      s.exec(sql)
    end
  end

  class << self

    # Return all managers defined in this application.

    def managers
      managers = []
      ObjectSpace.each_object(self) { |o| managers << o }
      return managers
    end

    # Is the given class managed by any manager?

    def managed?(klass)
      self.managers.any? { |m| m.managed? klass }
    end

    # Remove the classes managed by all managers.

    def managed_classes
      managed = self.managers.collect { |m| m.managed_classes }
      managed.flatten
    end

  end # self

end

end
