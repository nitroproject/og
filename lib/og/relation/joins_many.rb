#require 'facets/hash/insert'

require "og/relation"
require "og/collection"
require "og/util/inflect"

module Og

class JoinsManyCollection < Collection
end

# A 'joins_many' relation.
# This objects is associated with an other using an intermediate 
# join table.
#
# Examples:
#
#   joins_many :categories
#   joins_many Category
#   joins_many :categories, MyCategory
#
#--
# TODO: Find a way to replace Og.quote with something more 
# specific.
#++

class JoinsMany < Relation
  ann :self, :collection => true # marker

  #--
  # FIXME: better enchant polymorphic parents and then add 
  # an alias to :objects.
  #++
  
  def resolve_polymorphic
    target_class.module_eval <<-EOS, __FILE__, __LINE__
      joins_many :#{owner_class.to_s.demodulize.underscore.pluralize}
    EOS
  end

  def enchant
    self[:owner_singular_name] = owner_class.to_s.demodulize.underscore.downcase 
    self[:target_singular_name] = target_plural_name.to_s.singular

    owner_class.ogmanager.with_store do |store|
      # handle schema_inheritance
      
      join_class = owner_class.table_class
      # postfix the join name to the table name
      
      if self[:name] == self[:target_class].to_s.demodulize.underscore.downcase.plural
        join_table_info = store.join_table_info(self)
      else
        join_table_info = store.join_table_info(self, "_#{self.name}")
      end
      
      if through = self[:through]
        # A custom class is used for the join. Use the class 
        # table and don't create a new table.

        through = Relation.symbol_to_class(through, owner_class) if through.is_a?(Symbol)
        join_table = self[:join_table] = store.table(through)
        
        tmp_join_class = through
      else    
        # Calculate the name of the join table.

        join_table = self[:join_table] = join_table_info[:table]

        # Create a join table.

        owner_class.ann!(:self)[:join_tables] ||= []
        owner_class.ann!(:self, :join_tables) << join_table_info
        
        # Create temporary classes to be able to use ann.descendants to cascade
        # delete joins_many relations when one side of the relation is removed.
        
        tmp_join_class_name = "OgTempJ_#{join_table}"
        
        unless self.class.constants.include?(tmp_join_class_name)
          tmp_join_class = self.class.const_set(tmp_join_class_name, Class.new)
          tmp_join_class.const_set('OGTABLE', join_table)
        else
          tmp_join_class = self.class.const_get(tmp_join_class_name)
        end
      end
      
      owner_key = join_table_info[:owner_key]
      target_key = join_table_info[:target_key]
      
      # Add join class to ann(:descendants) to be able to use cascade deletes.

      owner_class.ann!(:self)[:descendants] ||= []
      owner_class.ann!(:self, :descendants) << [tmp_join_class, owner_key]

      owner_class.module_eval <<-EOS, __FILE__, __LINE__
        attr_accessor :#{target_plural_name}

        def #{target_plural_name}(options = nil)
          reload = options and options[:reload]

          unless @#{target_plural_name}
            @#{target_plural_name} = JoinsManyCollection.new(
              self, 
              #{target_class},
              :add_#{target_singular_name},
              :remove_#{target_singular_name},
              :find_#{target_plural_name},
              :count_#{target_plural_name},
              options
            )
          end

          @#{target_plural_name}.find_options = options
          @#{target_plural_name}.reload(options) if options and options[:reload]
          @#{target_plural_name}
        end

        def add_#{target_singular_name}(obj, options = nil)
          return unless obj
          obj.save if obj.unsaved?
          obj.class.ogmanager.with_store do |s|
            s.join(self, obj, "#{join_table}", options)
          end
        end

        def remove_#{target_singular_name}(obj)
          obj.class.ogmanager.with_store do |s|
            s.unjoin(self, obj, "#{join_table}")
          end
        end

        def find_#{target_plural_name}(options = {})
          find_options = {
            :join_table => "#{join_table}",
            :join_condition => "#{join_table}.#{target_key}=\#{#{target_class}::OGTABLE}.oid",
            :condition => "#{join_table}.#{owner_key}=\#{Og.quote(#{owner_class.primary_key})}"          
          }
          if options
            if condition = options.delete(:condition)
              find_options[:condition] += " AND (\#{condition})"
            end        
            find_options.update(options)
          end        
          #{target_class}.find(find_options)
        end      

        def count_#{target_plural_name}(options = nil)
          find_options = {
            :join_table => "#{join_table}",
            :join_condition => "#{join_table}.#{target_key}=\#{#{target_class}::OGTABLE}.oid",
            :condition => "#{join_table}.#{owner_key}=\#{Og.quote(#{owner_class.primary_key})}"
          }
          if options
            if condition = options.delete(:condition)
              find_options[:condition] += " AND (\#{condition})"
            end
            find_options.update(options)
          end
          #{target_class}.count(find_options)
        end
      EOS
      
      if through
        owner_class.module_eval <<-EOS, __FILE__, __LINE__
          def #{target_singular_name}_join_data(t)
            #{through}.find_one(:condition => "#{owner_key}=\#{Og.quote(#{owner_class.primary_key})} and #{target_key}=\#{Og.quote(t.pk)}")
          end
        EOS
      end    
    end
  end

end

end
