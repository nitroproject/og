require "facets/paramix"

require "og/util/inflect"

module Og::Mixin

# Implements the Nested Sets pattern for hierarchical
# SQL queries.
#--
# TODO: use active collections.
#++

module NestedSets

  def self.included_with_parameters(base, options = {})
    parent = base.to_s.demodulize.underscore.downcase
    c = {
      :left => 'lft',
      :right => 'rgt',
      :type => Fixnum,
      :parent => parent,
      :children => parent.plural
    }.update(options)

    parent = "#{c[:parent]}_oid"
    left = c[:left]
    right = c[:right]
    children = c[:children]
    child = c[:parent]

     if c[:scope].is_a?(Symbol) && c[:scope].to_s !~ /_oid$/
      c[:scope] = "#{c[:scope]}_oid".intern
    end

    scope = c[:scope]

    if scope
      if scope.is_a?(Symbol)
        scope = %{(#{scope} ? "#{scope} = \#{@#{scope}}" : "#{scope} IS NULL")}
      end

      cond = 'condition => ' + scope
      cond_and = ':condition => ' + scope + ' + " AND " +'
    else
      cond = ':condition => nil'
      cond_and = ':condition => '
    end

    base.module_eval <<-EOE, __FILE__, __LINE__    
      attr_accessor :#{parent}, Fixnum, :sql_index => true, :control => :none
      attr_accessor :#{left}, :#{right}, #{c[:type]}, :control => :none

      def root?
        (@#{parent}.nil? || @#{parent} == 0) && (@#{left} == 1) && (@#{right} > @#{left})
      end

      def child?
        (@#{parent} &&  @#{parent} != 0) && (@#{left} > 1) && (@#{right} > @#{left})
      end

      def parent
        if root?
          nil
        else
          #{base}[@#{parent}]
        end
      end

      def #{children}_count
        return (@#{right} - @#{left} - 1)/2
      end

      def full_#{children}(options = {})
        options.update(#{cond_and}"(#{left} BETWEEN \#\{@#{left}\} AND \#{@#{right}})")
        #{base}.all(options)
      end

      def #{children}(options = {})
        options.update(#{cond_and}"(#{left} > \#\{@#{left}\}) AND (#{right} < \#{@#{right}})")
        #{base}.all(options)
      end

      def direct_#{children}(options = {})
        options.update(#{cond_and}"#{parent} = \#{pk}")
        #{base}.all(options)
      end

      def add_#{child}(child)
        self.reload if pk
        child.reload if child.pk

        if @#{left}.nil? || @#{left} == 0 || @#{right}.nil? || @#{right} == 0
          @#{left} = 1
          @#{right} = 2 
        end

        child.#{parent} = pk
        child.#{left} = pivot = @#{right}
        child.#{right} = pivot + 1
        @#{right} = pivot + 2

        #{base}.transaction do
          #{base}.update("#{left} = (#{left} + 2)",  #{cond_and}"#{left} >= \#{pivot}")
          #{base}.update("#{right} = (#{right} + 2)", #{cond_and}"#{right} >= \#{pivot}")
        end

        self.save
        child.save
      end
    EOE
  end

end

# Transform the base class to a hierarchical node.
# A selection of different implementation strategies
# are provided.
#
# === Example
#
# class Comment
#    is Hierarchical, :method => :nested_sets
# end
#
# [+:method+]
#   :simple
#   :nested_sets
#   :nested_intervals

module Hierarchical

  def self.included_with_params(base, options)
    o = {
      :method => :nested_sets, 
    }
    o.update(options) if options

    base.include(NestedSets, o)
  end

end

end
