# gmosx: Work in progress.

module Caboose

  module EZ
    # EZ::Condition plugin for generating the :conditions where clause
    # for ActiveRecord::Base.find. And an extension to ActiveRecord::Base
    # called AR::Base.find_with_conditions that takes a block and builds
    # the where clause dynamically for you.

    class AbstractClause

      attr_reader :test
      attr_accessor :outer

      def to_sql; 'TRUE'; end

    end

    class Clause < AbstractClause
      # need this so that id doesn't call Object#id
      # left it open to add more methods that
      # conflict when I find them
      [:id].each { |m| undef_method m if method_defined?(m) }

      attr_reader :name, :test, :value

      # Initialize a Clause object with the name of the
      # column.
      def initialize(*args)
        @table_prefix = ''
        @negate = false
        case args.length
        when 0
          raise 'Expected at least one parameter'
        when 1
          @name = args.first.to_s
        when 2
          @table_prefix = args[0].to_s + '.' unless args[0].to_s.empty?
          @name = args[1].to_s
        when 3
          @table_prefix = args[0].to_s + '.' unless args[0].to_s.empty?
          @name = args[1].to_s
          @negate = args[2]
        end
        # append ! to negate the statement
        if @name[-1,1] == '!'
          @negate = true
          @name = @name.slice(0, @name.length - 1)
        end
        # prefix with esc_ to avoid clashes with standard methods like 'alias'
        @name = @name.slice(4, @name.length) if @name =~ /^esc_.*/
      end

      # The == operator has been over-ridden here to
      # stand in for an exact match ["foo = ?", "bar"]
      def ==(other)
        @test = :equals
        @value = other
      end

      # The =~ operator has been over-ridden here to
      # stand in for the sql LIKE "%foobar%" clause.
      def =~(pattern)
        @test = :like
        @value = pattern
      end

      # The spaceship <=> operator has been over-ridden here to
      # stand in for the sql ["BETWEEN ? AND ?", 1, 5] "%foobar%" clause.
      def <=>(range)
        @test = :between
        @value = range
      end

      # The === operator has been over-ridden here to
      # stand in for the sql ["IN (?)", [1,2,3]] clause.
      def ===(range)
        @test = :in
        @value = range
      end

      # switch on @test and build appropriate clause to
      # match the operation.
      def to_sql
        case @test
        when :equals
          if @value == :null
            @negate ? ["#{@table_prefix}#{@name} IS NOT NULL"] : ["#{@table_prefix}#{@name} IS NULL"]
          else
            @negate ? ["#{@table_prefix}#{@name} != ?", @value] : ["#{@table_prefix}#{@name} = ?", @value]
          end
        when :like
          @negate ? ["#{@table_prefix}#{@name} NOT LIKE ?", @value] : ["#{@table_prefix}#{@name} LIKE ?", @value]
        when :between
          @negate ? ["#{@table_prefix}#{@name} NOT BETWEEN ? AND ?", @value.begin, @value.end] : ["#{@table_prefix}#{@name} BETWEEN ? AND ?", @value.begin, @value.end]
        when :in
#          @negate ? ["#{@table_prefix}#{@name} NOT IN (?)", @value.to_a] : ["#{@table_prefix}#{@name} IN (?)", @value.to_a]
          @negate ? ["#{@table_prefix}#{@name} NOT IN (?*)", @value.to_a] : ["#{@table_prefix}#{@name} IN (?*)", @value.to_a]
        else
          ["#{@table_prefix}#{@name} #{@test} ?", @value]
        end
      end

      # This method_missing takes care of setting
      # @test to any operator thats not covered
      # above. And @value to the value
      def method_missing(name, *args)
        @test = name
        @value = args.first
      end
    end

    class ArrayClause < AbstractClause

      # wraps around an Array in ActiveRecord format ['column = ?', 2]

      def initialize(cond_array)
        @test = :array
        @cond_array = cond_array
      end

      def to_sql
        return nil if @cond_array.first.to_s.empty?
        query = (@cond_array.first =~ /^\([^\(\)]+\)$/) ? "#{@cond_array.first}" : "(#{@cond_array.first})"
        [query, @cond_array[1..@cond_array.length] ]
      end

    end

    class SqlClause < AbstractClause

      # wraps around a raw SQL string

      def initialize(sql)
        @test = :sql
        @sql = sql
      end

      def to_sql
        [@sql]
      end

    end

  end # EZ

end # Caboose
