# gmosx: Work in progress.

module Caboose

  module EZ
    # EZ::Condition plugin for generating the :conditions where clause
    # for ActiveRecord::Base.find. And an extension to ActiveRecord::Base
    # called AR::Base.find_with_conditions that takes a block and builds
    # the where clause dynamically for you.

    class Condition
      # need this so that id doesn't call Object#id
      # left it open to add more methods that
      # conflict when I find them
      [:id].each { |m| undef_method m if method_defined?(m) }

      # these are also reserved words regarding SQL column names
      # use esc_* prefix to circumvent any issues
      attr_reader :clauses
      attr_accessor :inner
      attr_accessor :outer

      # Initialize @clauses and eval the block so
      # it invokes method_missing.
      def initialize(*args, &block)
        options = args.last.is_a?(Hash) ? args.last : {}
        options[:table_name] = args.first if args.first.kind_of? Symbol
        @table_name = options.delete(:table_name) || nil
        @outer = options.delete(:outer) || :and
        @inner = options.delete(:inner) || :and
        @clauses = []
        instance_eval(&block) if block_given?
      end

      # When invoked with the name of the column in each statement inside the block:
      # A new Clause instance is created and recieves the args. Then the operator
      # hits method_missing and gets sent to a new Clause instance where it either
      # matches one of the defined ops or hits method_missing there.
      #
      # When invoked with an attached block a subcondition is created. The name
      # is regarded as the table_name, additional parameters for outer and inner
      # are passed on.
      def method_missing(name, *args, &block)
        if block_given?
          # handle name as table_name and create a subcondition
          options = args.last.is_a?(Hash) ? args.last : {}
          options[:table_name] ||= name
          define_sub(options, &block)
        else
          clause(name, *args)
        end
      end

      # You can define clauses dynamicly using this method. It will take a
      # clause and create the correct Clause object to process the conditions
      def clause(name, *args)
        if name.kind_of?(Array)
          c = Clause.new(name.first, name.last)
        elsif args.last.kind_of?(Symbol)
          c = Clause.new(args.pop, name)
        else
          c = Clause.new(@table_name, name)
        end
        @clauses << c
        c
      end

      # Create subcondition from a block, optionally specifying table_name, outer and inner.
      # :outer determines how the subcondition is added to the condition, while :inner
      # determines the internal 'joining' of conditions inside the subcondition. Both
      # :inner & :outer defult to 'AND'
      def define_sub(*args, &block)
        options = args.last.is_a?(Hash) ? args.last : {}
        options[:table_name] = args.first if args.first.kind_of? Symbol
        options[:table_name] ||= @table_name
        cond = Condition.new(options, &block)
        self << cond
      end

      # Aliases for syntax convenience. :sub or :condition map to :define_sub
      alias_method :sub, :define_sub
      alias_method :condition, :define_sub

      # Shortcut for adding a :and boolean joined subcondition
      def and_condition(*args, &block)
        options = args.last.is_a?(Hash) ? args.last : {}
        options[:table_name] = args.first if args.first.kind_of? Symbol
        options[:outer] ||= @outer
        options[:inner] ||= :and
        define_sub(options, &block)
      end

      # Alias :all to be shorthand for :and_condition
      alias_method :all, :and_condition

      # Shortcut for adding a :or boolean joined subcondition
      def or_condition(*args, &block)
        options = args.last.is_a?(Hash) ? args.last : {}
        options[:table_name] = args.first if args.first.kind_of? Symbol
        options[:outer] ||= @outer
        options[:inner] ||= :or
        define_sub(options, &block)
      end

      # Alias :any to stand in for :or_condition
      alias_method :any, :or_condition

      # Append a condition element, which can be one of the following:
      # - String: raw sql string
      # - ActiveRecord instance, for attribute or PK cloning
      # - Condition or Clause with to_sql method and outer property
      # - Array in ActiveRecord format ['column = ?', 2]
      def <<(condition, outer = nil)
        if condition.kind_of?(String) and not condition.to_s.empty?
          cond = SqlClause.new(condition)
          cond.outer = outer || :and
          @clauses << cond
        elsif condition.kind_of?(Og::Model)
          if condition.attributes[condition.class.primary_key].nil?
            condition.attributes.each { |k, v| clause([condition.class.table_name, k]) == v unless v.to_s.empty? }
          else
            clause([condition.class.table_name, condition.class.primary_key]) == condition.attributes[condition.class.primary_key]
          end
        else
          if condition.kind_of?(Condition) or condition.kind_of?(AbstractClause)
            logic = condition.outer if outer.nil?
            condition = condition.to_sql
          else
            logic = outer
          end
          if condition.kind_of?(Array) and not condition.empty?
            array_clause = ArrayClause.new(condition)
            array_clause.outer = logic
            @clauses << array_clause
          end
        end
      end

      # Aliases for :<<, the method itself deals with what kind
      # of condition you are appending to the chain so these
      # aliases are for a nicer syntax's sake.
      alias_method :sql_condition, :<<
      alias_method :add_sql, :<<
      alias_method :clone_from, :<<
      alias_method :append, :<<

      # Loop over all Clause onjects in @clauses array
      # and call to_sql on each instance. Then join
      # the queries and params into the :conditions
      # array with logic defaulting to AND.
      # Subqueries are joined together using their
      # individual outer property setting if present.
      # Also defaults to AND.
      def to_sql(logic=@inner)
        params = []; query = []
        @clauses.each do |cv|
          q, p, e = cv.to_sql
          unless q.to_s.empty?
            logic = cv.outer ? cv.outer : logic
            logic = logic.to_s.upcase
            logic = 'AND NOT' if logic == 'NOT'
            query << logic unless query.empty?
            query << q
            if cv.test == :in
              params << p if p.respond_to?(:map)
            elsif p.kind_of?(Array)
              p.flatten! unless q =~ /IN/
              params += p
            else
              params << p unless p.nil?
              params << e unless e.nil?
            end
          end
        end
        [query.join(' '), *params ]
      end
    end

  end # EZ module

end # Caboose module
