# = Og
#
# Copyright (c) 2004-2007, George Moschovitis (http://www.gmosx.com)
#
# Og (http://www.nitroproject.org) is copyrighted free software
# created and maintained by George Moschovitis
# (mailto:george.moschovitis@gmail.com) and released under the
# standard BSD Licence. For details consult the file doc/LICENCE.

require "English"
require "pp"

require 'language/mixin'
require 'english/inflect'

Language.current = 'en'

require "facets"
require "facets/synchash"
require "facets/syncarray"
require "facets/logger"
require "facets/nullclass"
#require "facets/stylize"
require "facets/attr"

require "og/global_logger"

require "og/aspects"
require "facets/settings"

require 'og/glue'

require "anise"

require "paramix" # keep this before module/is

require "facets/module/is"
require "facets/class/cattr"

class NilClass # :nodoc: all
  # quite usefull for error tolerant apps.
  # a bit dangerous? Will have to rethink this.

  def empty?
    true
  end

  def blank?
    true
  end
end

class Class # :nodoc: all
  #--
  # gmosx: is this really needed?
  #++

  def to_i
    return self.hash
  end
end

module Kernel # :nodoc: all

  # Pretty prints an exception/error object
  # usefull for helpfull debug messages
  #
  # Input:
  # The Exception/StandardError object
  #
  # Output:
  # the pretty printed string

  def pp_exception(ex)
    return %{#{ex.message}\n  #{ex.backtrace.join("\n  ")}\n  LOGGED FROM: #{caller[0]}}
  end
end


# Og (ObjectGraph) manages Ruby objects and their relations and
# provides transparent and efficient object-relational mapping
# and querying mechanisms.
#
# === Property Metadata
#
# Og defines, reserves and uses the following property
# metadata types:
#
# [+:sql_index+]
#    Create an sql index for this property.
#
# [+:unique+]
#    This value of the property must be unique.
#
# === Design
#
# Og allows the serialization of arbitrary Ruby objects. Just
# mark them as Object (or Array or Hash) in the attr_accessor
# and the engine will serialize a YAML dump of the object.
# Arbitrary object graphs are supported too.

module Og

  # The version.

  Version = "0.50.0"

  # Library path.

  LibPath = File.dirname(__FILE__)

  # If true, check for implicit changes in the object
  # graph. For example when you add an object to a parent
  # the object might be removed from his previous parent.
  # In this case Og emits a warning.
  # Address of the Og cache (if distributed caching enabled).

  setting :cache_address, :default => '127.0.0.1', :doc => 'Address of the Og cache'

  # Port of the Og cache (if distributed caching enabled).

  setting :cache_port, :default => '9070', :doc => 'Port of the Og cache'

  setting :check_implicit_graph_changes, :default => false, :doc => 'If true, check for implicit changes in the object graph'

  # If true, Og tries to create/update the schema in the
  # data store. For production/live environments set this to
  # false and only set to true when the object model is
  # upadated. For debug/development environments this should
  # stay true for convienience.

  setting :create_schema, :default => true, :doc => 'If true, Og tries to create/update the schema in the data store'

  # The DBI version of the default setup options for Og managers.
  # The dbi_options accessor is aliased as manager_options
  # *[manager_options DEPRECATED]*
  # ==== Required Manager Options
  # - +:store+
  # - +:adapter+
  # - +:name+
  # Specific stores and adapters may require additional options,
  # see the documentation for each particular store or adapter
  # for further details.

  #  setting :default_options,
  #          :default => { :adapter => :dbi, :dbd => :sqlite, :name => :memory,
  #          :evolve_schema => :warn, :qualified_field_names => false },
  #          :doc => 'The default setup for Og managers'

  # If true, Og destroys the schema on startup. Useful while
  # developing / debugging.

  setting :destroy_schema, :default => false, :doc => 'If true, Og destroys the schema on startup'

  # The default setup for Og managers.

  setting :manager_options, :default => { :adapter => :sqlite, :name => :memory, :evolve_schema => :warn }, :doc => 'The default setup for Og managers'

  # If true raises exceptions on store errors, usefull when
  # debugging. For production environments it should probably be
  # set to false to make the application more fault tolerant.

  setting :raise_store_exceptions, :default => true, :doc => 'If true raises exceptions on store errors'


  # If true, only allow reading from the database. Useful
  # for maintainance.
  # WARNING: not implemented yet.

  setting :read_only_mode, :default => false, :doc => 'If true, only allow reading from the database'

  # Prepend the following prefix to all generated SQL table names.
  # Usefull on hosting scenarios where you have to run multiple
  # web applications/sites on a single database.
  #
  # Don't set the table_prefix to nil, or you may face problems
  # with reserved words on some RDBM systems. For example User
  # maps to user which is reserved in postgresql). The prefix
  # should start with an alphanumeric character to be compatible
  # with all RDBM systems (most notable Oracle).
  #--
  # TODO: move this to the sql store.
  #++

  setting :table_prefix, :default => 'og', :doc => 'Prepend the prefix to all generated SQL table names'

  # Enable/dissable thread safe mode.
  # setting :thread_safe, :default => true, :doc => "Enable/dissable thread safe mode"

  # A collection of classes that are unmanageable, ie the manager
  # should ignore them.

  setting :unmanageable_classes, :default => [], :doc => 'Explicitly unmanageable classes'

  # If set to true, use UUIDs as primary keys.

  setting :use_uuid_primary_keys, :default => false, :doc => "Use UUIDs as primary keys"

  # Pseudo type for binary data.

  class Blob; end

  # Mixin namespace. Included in the toplevel for convienience

  module Mixin; end

  # Root type of Og exceptions, defined closer to their common usage
  class Exception < ::Exception; end

  class << self

    # The active manager

    attr_accessor :manager

    # thread safe state

    attr_reader :thread_safe

    # Helper method, useful to initialize Og.
    # If no options are passed, sqlite is selected
    # as the default store.

    def start(options = Og.manager_options)
      # Use sqlite as the default adapter.
      @options={}
      @options.update(Og.manager_options) if options == {}
      @options.update(options)
      @options[:adapter] = :sqlite unless @options[:adapter] || @options[:store]

      # THINK: Check if adapter == dbi and throw exception if
      # dbi_driver == nil?
      # Is the extra overhead worth it or should we only ever
      # instruct users to set :dbi_driver?
      # If throw an exception, here or in Member#initialize?

      @options[:adapter] = :dbi if @options[:dbi_driver]

      # This is a flag a store or manager can use to determine
      # if it was being called by Og.setup to provide
      # additional, faster or enhanced functionality.

      @options[:called_by_og_setup] = true if @options[:called_by_og_setup].nil?

      @thread_safe = Og.thread_safe

      m = @manager = Manager.new(@options)
      m.manage_classes(@options[:classes])

      # Allows functionality that requires an initialized
      # store to be implemented. A vastly superior
      # method of constructing foreign key constraints is an
      # example of functionality this provides. Currently
      # only used by the PostgreSQL store.

      m.post_setup if @options[:called_by_og_setup]

      return m
    rescue Exception => ex
      error "#{ex.class} in Og.setup:"
      error ex.message
      if $DBG # THINK: is this needed?
        error ex.backtrace.join("\n")
        exit
      end
    end
    alias_method :run, :start
    alias_method :connect, :start
    # The following is deprecated, used for compatibility.
    alias_method :setup, :start
    alias_method :setup=, :start

    # Helper method.

    def escape(str)
      @manager.with_store { |s| s.escape(str) }
    end

    # Quote the string.

    def quote(str)
      @manager.with_store { |s| s.quote(str) }
    end

    # Change thread_safe mode.

    def thread_safe=(bool)
      @thread_safe = bool
#      @manager and @manager.class.managers.each { |m| m.initialize_store }
      return @thread_safe
    end

    def initialized?
      !@manager.nil?
    end
  end # self

end

# Include Og::Mixin in the Toplevel for convienience.

include Og::Mixin

#--
# gmosx: leave this here.
#++

require "og/util/ann_attr"
require "og/manager"
require "og/errors"
require "og/autoload"

require "og/util/types"
require "og/validation"
