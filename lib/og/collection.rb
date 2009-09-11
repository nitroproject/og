module Og

# An 'active' collection that reflects a relation. A collection 
# stores entitities that participate in a relation.

class Collection

  include Enumerable
  
  # The owner of this collection.
  
  attr_accessor :owner
  
  # The members of this collection. Keeps the objects
  # that belong to this collection.
  
  attr_accessor :members

  # When the collection is in building mode or the owner
  # object is unsaved, added members are accumulated in the
  # building_memebers array. These relations are serialized
  # when the owner object is saved (or when save_building_members
  # is explicitly called).
  
  attr_accessor :building_members
  
  # The class of the members of this collection.

  attr_accessor :member_class

  # A method used to add insert objects in the collection.
   
  attr_accessor :insert_proc

  # A method used to remove objects from the collection.
  
  attr_accessor :remove_proc
  
  # A method used to find the objects that belong to the
  # collection.
  
  attr_accessor :find_proc

  # A method used to count the objects that belong to the
  # collection.
  
  attr_accessor :count_proc
  
  # The default find options.
  
  attr_accessor :find_options
  
  # Is the collection in build mode?
  
  attr_accessor :building
  
  # Is the collection loaded?
  
  attr_accessor :loaded

  # Initialize the collection.
    
  def initialize(owner = nil, member_class = nil, insert_proc = nil, 
      remove_proc = nil, find_proc = nil, 
      count_proc = nil, find_options = {})
    @owner = owner
    @member_class = member_class
    @insert_proc = insert_proc
    @remove_proc = remove_proc
    @find_proc = find_proc
    @count_proc = count_proc
    @find_options = find_options
    @members = []
    @loaded = false
    @building = false
  end

  # Load the members of the collection.  

  def load_members
    unless @loaded or @owner.unsaved?
      @members = @owner.send(@find_proc, @find_options)
      @loaded = true
    end
    @members
  end
  
  # Reload the collection.
  
  def reload(options = {})
    # gmosx, NOOO: this was a bug! it corrupts the default options.
    #  @find_options = options
    @members = @owner.send(@find_proc, options)
  end

  # Unload the members (clear the cache).
  
  def unload
    @members.clear
    @loaded = false
  end
  
  # Convert the collection to an array.
    
  def to_ary
    load_members
    @members
  end

  # Defined to avoid the method missing overhead.
  
  def each(&block)
    load_members
    @members.each(&block)
  end
  
  # Defined to avoid the method missing overhead.
  
  def [](idx)
    load_members
    @members[idx]
  end
  
  # Add a new member to the collection.
  # this method will overwrite any objects already
  # existing in the collection.
  #
  # If the collection is in build mode or the object
  # is unsaved, the member is accumulated in a buffer. All
  # accumulated members relations are saved when the object
  # is saved.
  
  def push(obj, options = nil)
    remove(obj) if members.include?(obj)
    @members << obj
    unless @building or owner.unsaved?
      @owner.send(@insert_proc, obj, options)
    else
      (@building_members ||= []) << obj
      @owner.instance_variable_set '@pending_building_collections', true
    end
  end
  alias_method :<<, :push
  alias_method :add, :push

  # Remove a member from the collection, the actual object
  # is not deleted.
  
  def delete(*objects)
    objects = objects.flatten
    return if objects.empty?

    @owner.transaction do
      objects.each do |obj|
        if @member_class === objects[0]
          @members.delete(obj)
        else
          @members.delete_if {|x| x.pk == obj }
        end
      end
    end
  end

  # Delete a member from the collection AND the store.
  
  def delete!(*objects)
    objects = objects.flatten
    return if objects.empty?

    @owner.transaction do
      objects.each do |obj|
        @member_class.delete(obj) if obj.saved?
        
        if @member_class === objects[0]
          @members.delete(obj)
        else
          @members.delete_if { |x| x.pk == obj }
        end
        
      end
    end
  end

  # Delete a member from the collection AND the store, if the
  # condition block evaluates to true.

  def delete_if(&block)
    objects = @members.select(&block)

    objects.reject! { |obj| @members.delete(obj) if obj.unsaved? }
    return if objects.empty?

    @owner.transaction do
      objects.each do |obj|
        obj.delete
        @members.delete(obj)
      end
    end
  end

  # Remove all members from the collection.
  
  def remove_all
    @owner.transaction do
      self.each { |obj| @owner.send(@remove_proc, obj) }
    end
    @members.clear
    @loaded = false # gmosx: IS this needed?
  end
  alias_method :clear, :remove_all

  # Delete all members of the collection. Also delete from the
  # store.
  
  def delete_all
    @owner.transaction do
      self.each { |obj| obj.delete }
    end
    @members.clear
  end

  # Return the size of a collection.
  
  def size(reload = false)
    if @loaded and !reload
      return @members.size
    else
      return @owner.send(@count_proc)
    end
  end
  alias_method :count, :size

  # Allows to perform a scoped query.
  
  def find(options = {})
    tmp = nil
    @member_class.with_scope(options) do
      tmp = @owner.send(@find_proc, @find_options)
    end
    return tmp
  end

  # Find one object.
  
  def find_one options = {}
    find(options).first
  end

  # In building mode, relations for this collection are 
  # accumulated in @building_relations. These relations are
  # saved my calling this method.
  
  def save_building_members(options = nil)
    return unless @building_members
    
    for obj in @building_members
      @owner.send(@insert_proc, obj, options)
    end
    @building_members = nil
  end
  
  # Try to execute an accumulator or else
  # redirect all other methods to the members array.
  #
  # An example of the accumulator:
  #
  # foo_foobars = foo1.bars.foobars
  
  def method_missing(symbol, *args, &block)
    load_members
    if @member_class.instance_methods.include? symbol.to_s
      @members.inject([]) { |a, x| a << x.send(symbol) }.flatten
    else
      @members.send(symbol, *args, &block)
    end
  end
  
end

end
