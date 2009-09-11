require "og/relation"

module Og

# A refers to relation. Stores the foreign key in the object.
#
# Options:
#
# * :field sets the field used in the database schema.
# * :foreign_name overrides the deafult foreign name.
# * :create_on_insert creates the target object when the
#   referrer is inserted, example:
#   
#   class User
#     has_one :profile, :create_on_insert => true
#   end
#--
# TODO: No need to save user (should only call save aspects, for
# example sweepers)
#
# THINK: Investigate if we should only store the key in the 
# foreign object.
#++

class RefersTo < Relation

  def self.foreign_key(rel)
    "#{rel[:foreign_name] || rel[:target_singular_name]}_#{rel[:target_class].primary_key}"
  end

  def enchant
    raise "#{target_singular_name} in #{owner_class} refers to an undefined class" if target_class.nil?
    
    self[:foreign_key] ||= "#{foreign_name || target_singular_name}_#{target_class.primary_key}"

    if self[:field]
      field = ", :field => :#{self[:field]}"
    end 

    target_primary_key_class = target_class.ann(target_class.primary_key, :class)
    
    owner_class.ogmanager.with_store do |store|
      join_table_info = store.join_table_info(self)
      owner_key = join_table_info[:owner_key]
      
      owner_class.module_eval <<-EOS, __FILE__, __LINE__
        attr_accessor :#{foreign_key}, #{target_primary_key_class}#{field}, :relation => true

        def #{target_singular_name}(reload = false)
          return nil if @#{foreign_key}.nil? 

          # will reload if forced or first load or
          if reload or not @#{target_singular_name}
            @#{target_singular_name} = #{target_class}[@#{foreign_key}]
          end
          @#{target_singular_name}
        end

        def #{target_singular_name}=(obj)
          obj.save if obj.unsaved? unless obj.nil?
          if obj
            @#{foreign_key} = obj.#{target_class.primary_key}
            self.save if self.unsaved?
            if obj.instance_variable_get('@#{owner_key}') != pk
              obj.instance_variable_set('@#{owner_key}', pk)
              obj.save
            end
          end
          return obj
        end
      EOS

      # Add code to create the target object if create_on_insert == true.
      #--
      # gmosx, TODO: optimize the create_on_insert_xxx method.
      #++
         
      if self[:create_on_insert]
        owner_class.module_eval <<-EOS, __FILE__, __LINE__
          after :create_on_insert_#{target_singular_name}, :on => :og_insert
          
          private
          
          def create_on_insert_#{target_singular_name}
            self.#{target_singular_name} = __#{target_singular_name} = #{target_class}.create
            __#{target_singular_name}.save
            self.save
          end
        EOS
      end    
    end
  end

end

end
