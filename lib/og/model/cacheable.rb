require "facets/classmethods"

module Og::Mixin

# Include this module in your Og managed classes to make
# them cacheable. Only queries by id are cached.
#
# If you use a distributed cache (drb, memcache, etc) , you may 
# have to start a separate server.
#--
# TODO: Recode with Aspects.
#
# gmosx, WARNING: If the file lib/og/model.rb is changed
# this file should be updated to reflect the changes!
#++

module Cacheable

  class_methods do
  
    def after_enchant(base)
      base.module_eval do

        alias_method :save_without_cache, :save      
        def save(options = nil)
          Cacheable.cache_delete(self.class, pk)
          val = save_without_cache(options)
          Cacheable.cache_set(self)
          return val
        end
        alias_method :save!, :save
        alias_method :validate_and_save, :save

        alias_method :force_save_without_cache!, :force_save!      
        def force_save!(options = nil)
          Cacheable.cache_delete(self.class, pk)
          val = force_save_without_cache!(options)
          Cacheable.cache_set(self)
          return val
        end

        alias_method :insert_without_cache, :insert      
        def insert
          insert_without_cache()
          Cacheable.cache_set(self)
          return self
        end

        alias_method :update_without_cache, :update      
        def update(options = nil)
          Cacheable.cache_delete(self.class, pk)
          val = update_without_cache(options)
          Cacheable.cache_set(self)
          return val
        end

        alias_method :update_properties_without_cache, :update_properties      
        def update_properties(*properties)
          Cacheable.cache_delete(self.class, pk)
          val = update_properties_without_cache(*properties)
          Cacheable.cache_set(self)
          return val
        end
        alias_method :update_property, :update_properties
        alias_method :pupdate, :update_properties

        alias_method :update_by_sql_without_cache, :update_by_sql      
        def update_by_sql(set)
          Cacheable.cache_delete(self.class, pk)
          val = update_by_sql_without_cache(sql)
          Cacheable.cache_set(self)
          return val
        end
        alias_method :update_sql, :update_by_sql
        alias_method :supdate, :update_by_sql

        alias_method :reload_without_cache, :reload      
        def reload
          Cacheable.cache_delete(self.class, pk)
          reload_without_cache()
          Cacheable.cache_set(self)
        end
        alias_method :reload!, :reload

        alias_method :delete_without_cache, :delete      
        def delete(cascade = true)
          delete_without_cache(cascade)
          Cacheable.cache_delete(self.class, pk)
        end
        
        def og_cache_key
          "#{self.class}:#{pk}"
        end
        
        class << self
          alias_method :load_without_cache, :load
          def load(pk)
            key = og_cache_key(pk)
            unless obj = ogmanager.cache.get(key)
              obj = load_without_cache(pk)
              ogmanager.cache.set(key, obj)
            end
            
            return obj
          end
          alias_method :[], :load
          alias_method :exist?, :load
          
          alias_method :delete_without_cache, :delete      
          def delete(obj_or_pk, cascade = true)
            delete_without_cache(obj_or_pk, cascade)
            Cacheable.cache_delete(self, obj_or_pk)
          end
          
          def og_cache_key(pk)
            "#{self}:#{pk}"  
          end          
                    
        end
        
      end
    end
    
  end

  # ...
  
  def self.cache_get(klass, pk)
    obj.class.ogmanager.cache.get(klass.og_cache_key(pk)) 
  end

  # ...
    
  def self.cache_set(obj)
    obj.class.ogmanager.cache.set(obj.og_cache_key, obj)         
  end

  # Invalidate the cache entry for an object. Og high level 
  # methods automatically call this method where needed. However 
  # if you manually alter the store using Og low level methods 
  # (for example a native SQL query) you should call this method 
  # explicitly.

  def self.cache_delete(klass, pk)
    #key = "og#{klass}:#{pk}"
    key = klass.og_cache_key(pk)
#   self.og_local_cache.delete(key)
    klass.ogmanager.cache.delete(key)
  end

end

end
