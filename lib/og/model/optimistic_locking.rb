#require "facets/module/on_included"

module Og::Mixin

# This error is thrown when you the object you are trynig
# to update is allready updated by another thread.

class StaleObjectError < StandardError
end

# Include this module into models to provide optimistic
# locking suport. For more information on optimistic locking
# please consult:
#
# http://c2.com/cgi/wiki?OptimisticLocking
# http://en.wikipedia.org/wiki/Optimistic_concurrency_control

module Locking
  attr_accessor :lock_version, Fixnum, :default => 0
  pre "@lock_version = 0", :on => :og_insert
  
  on_included %{
    base.module_eval do
      def self.enchant
        self.send :alias_method, :update_without_lock, :update
        self.send :alias_method, :update, :update_with_lock
        self.send :alias_method, :save_without_lock, :save
        self.send :alias_method, :save, :save_with_lock
      end
    end
  }
  
  def update_with_lock
    lock = @lock_version
    @lock_version += 1

    unless update_without_lock(:condition => "lock_version=#{lock}") == 1  
      raise(StaleObjectError, 'Attempted to update a stale object')
    end
  end

  def save_with_lock
    lock = @lock_version
    @lock_version += 1

    unless save_without_lock(:condition => "lock_version=#{lock}") == 1  
      raise(StaleObjectError, 'Attempted to update a stale object')
    end
  end
  
end

end
