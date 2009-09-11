module Og

# Raised when an local object refers to its persistent image which has been
# deleted in the meantime.  
# 
# Example
#   model = ModelClass[1]
#   sleep
#   # another thread
#   killhim = ModelClass[1]
#   killhim.delete!
#   # and then...
#   model.reload => raises Og::Deleted

class Deleted < Exception; end
  
# A Store is a backend of Og used to persist objects. An 
# adapter specializes the Store. For example the SQL Store
# has the MySQL, PostgreSQL, Sqlite3 etc adapters as 
# specializations.

class Store

  attr_accessor :ogmanager

  # Create a session to the store.
  #
  # Default options:
  #   :evolve_schema => :warn

  def initialize options
    @options = options
    @transaction_nesting = 0
  end

  # Close the session to the store.

  def close
  end
  
  # Enchants a class.

  def enchant(klass, manager)
    pk = klass.primary_key
    klass.module_eval %{
      # A managed object is considered saved if it has 
      # a valid primary key.
      
      def saved?
        return #{pk}
      end

      # The inverse of saved.
      
      def unsaved?
        return !#{pk}
      end

      # Evaluate an alias for the primary key.

      alias_method :pk, :#{pk}
      
      def pk=(the_pk)
        @#{pk} = the_pk
      end
    }
  end
    
  # :section: Lifecycle methods.

  # Loads an object from the store using the primary key.

  def load(pk, klass)
    raise NotImplementedError, 'load'
  end
  alias_method :exist?, :load

  # Reloads an object from the store.

  def reload(obj)
    raise NotImplementedError, 'reload'
  end

  # Save an object to store. Insert if this is a new object or
  # update if this is already inserted in the database. 
  #
  # Checks if the object is valid before saving. Throws a 
  # ValidationError if the object is invalid and populates
  # obj.validation_errors.

  def save(obj, options = nil)
    raise ValidationError.new(obj) unless obj.valid?

    if obj.saved?
      update_count = obj.og_update(self, options)
    else
      update_count = 1 if obj.og_insert(self)
    end

    # Save building collections if any.
    obj.save_building_collections
  
    return update_count
  end
  alias_method :<<, :save
  alias_method :validate_and_save, :save

  # Force the persistence of an Object. Ignore any validation
  # and/or other errors.
  
  def force_save!(obj, options)
    if obj.saved?
      obj.og_update self, options
    else
      obj.og_insert self
    end
  end

  # Insert an object in the store.

  def insert(obj)
    obj.og_insert(self)
  end

  # Update an object in the store.

  def update(obj, options = nil)
    obj.og_update self, options
  end

  # Update selected attributes of an object or class of
  # objects.
  
  def update_attributes(target, *attributes)
    update(target, :only => attributes)
  end
  alias_method :aupdate, :update_attributes
  alias_method :update_attribute, :update_attributes

  # Permanently delete an object from the store.

  def delete(obj_or_pk, klass = nil, cascade = true)
    unless obj_or_pk.is_a? Model
      # create an instance to keep the og_delete
      # method as an instance method like the other lifecycle
      # methods. This even allows to call og_delete aspects
      # that use instance variable (for example, sophisticated
      # cache sweepers).
      #
      # gmosx: the following is not enough!
      # obj = klass.allocate
      # obj.pk = obj_or_pk
      obj = klass[obj_or_pk]
      obj.og_delete(self, cascade)
    else
      obj_or_pk.og_delete(self, cascade)
    end
  end

  # Delete all instances of the given class.
  
  def delete_all(klass)
    raise "Not implemented"
  end

  # Perform a query.

  def find(klass, options)
    raise "Not implemented"
  end

  # Count the results returned by the query.

  def count(options)
    raise "Not implemented"
  end

  # :section: Transaction methods.

  # Start a new transaction.

  def start
    raise "Not implemented"
    true if @transaction_nesting < 1
    @transaction_nesting += 1
  end

  # Commit a transaction.

  def commit
    raise "Not implemented"
    @transaction_nesting -= 1
    true if @transaction_nesting < 1
  end

  # Rollback a transaction.

  def rollback
    @transaction_nesting -= 1
    true if @transaction_nesting < 1
  end

  # Transaction helper. In the transaction block use
  # the db pointer to the backend.

  def transaction
    start
    yield self
  rescue Object => ex
    rollback
    debug "#{ex.class}: #{ex.message}"
    ex.backtrace.each { |line| debug line }
  else
    commit
  end
  
  def transaction_raise
    start
    yield self
  rescue Object => ex
    rollback
    raise
  else
    commit
  end

end

end
