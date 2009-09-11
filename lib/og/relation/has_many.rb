require "og/relation"
require "og/collection"
require "og/util/inflect"
require "og/relation/belongs_to"

module Og

class HasManyCollection < Collection
end

# A 'has_many' relation. There should be a respective
# 'belongs_to' relation.
#
# Examples:
#
#   article.comments << Comment.new
#   article.comments.size

class HasMany < Relation
  ann :self, :collection => true # marker

  def resolve_polymorphic
    unless target_class.relations.empty?
      unless target_class.relations.find { |r| r.is_a?(BelongsTo) and  r.target_class == owner_class }
        target_class.belongs_to(owner_class)      
      end
    end
  end

  def enchant
    self[:owner_singular_name] = if owner_class.schema_inheritance?
      owner_class.schema_inheritance_root_class
    else
      owner_class
    end.to_s.demodulize.underscore.downcase
    
    self[:target_singular_name] = target_plural_name.to_s.singular
    self[:foreign_key] = "#{foreign_name || owner_singular_name}_#{owner_class.primary_key}"
    # gmosx: DON'T set self[:foreign_field]
    foreign_field = self[:foreign_field] || self[:foreign_key]
    
    owner_class.module_eval <<-EOS, __FILE__, __LINE__
      def #{target_plural_name}(options = nil)
        unless @#{target_plural_name}
          @#{target_plural_name} = HasManyCollection.new(
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
      
      def #{target_plural_name}=(*args)
        options = args.last.is_a?(Hash) ? args.pop : nil
        
        if args.size == 1 && args.first.is_a?(HasManyCollection)
          @#{target_plural_name} = args.first
          @#{target_plural_name}.find_options = options if options
          
          return @#{target_plural_name}
        end
        
        args.flatten!
        
        args.each do |obj|
          add_#{target_singular_name}(obj, options)
        end
        
        return #{target_plural_name}
      end

      def add_#{target_singular_name}(obj, options = nil)
        return unless obj
        # save the object if needed to generate a primary_key.
        self.save unless self.saved?
        obj.#{foreign_key} = @#{owner_class.primary_key}
        obj.save
      end

      def remove_#{target_singular_name}(obj)
        obj.#{foreign_key} = nil
        obj.save
      end
      
      def find_#{target_plural_name}(options = {})
        find_options = {
          :condition => "#{foreign_field} = \#{og_quote(#{owner_class.primary_key})}"
        }
        if options
          if condition = options.delete(:condition)
            find_options[:condition] += " AND (\#{condition})"
          end        
          find_options.update(options)
        end
        #{target_class}.find(find_options)
      end
      
      def count_#{target_plural_name}
        #{target_class}.count(:condition => "#{foreign_field} = \#{og_quote(#{owner_class.primary_key})}")        
      end
    EOS
  end

end

end
