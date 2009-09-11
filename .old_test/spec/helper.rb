$DBG = true

unless defined? SpecHelper

  SpecHelper = true

  # This file contains og initialization code for all tests. 
  # This way you only change the parameters in one file in 
  # order to run all the tests for many stores.
  #
  # Current store choices are
  #  :mysql :psql :sqlite :kirby :memory

  # CHANGE THIS TO SETUP MOST TESTS

  config = :mysql

  # SET THIS TO true TO ENABLE EXTRA DEBUG CODE

  # jl: if your specs silently fail, set debug.  Otherwise you'll 
  # get no backtraces or warnings.
  debug = $DBG

  unless debug
    # FIXME: jl: this is awful and nasty, but until OGTABLE 
    # is excised, it spews constant changed warnings - if you 
    # set debug then warnings will be issued.
    $VERBOSE=nil
  end

  # TO TEST AGAINST AN INSTALLATION OF OG INSTEAD THIS LOCAL 
  # DISTRIBUTION, SET THE FOLLOWING TO true.

  test_against_installation = false

  #--------------------------------------------------------------
  # DO NOT CHANGE ANYTHING BELOW THIS LINE

  unless test_against_installation
    $:.unshift File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "lib"))
    require "#{File.dirname(__FILE__)}/../../script/lib/glycerin"
  end

  $DBG = debug
  $og_config = config

  # This sets the common global vars to be used by the tests.

  require "script/lib/spec"
  require "stringio"
  require "glue"
  require "glue/logger"
  require "og"
  require "spec"

  Logger.get.level = Logger::FATAL unless $DBG

  module OgSpec
    OgConfigs = { 
      :mysql => {
      :adapter => :mysql,
      :user => "root",
      :password => ENV["DB_PASSWORD"]
    },
    :psql => {
      :adapter => :postgresql,
      :user => "postgres",
      :password => "postgres",
    },
    :sqlite => {
      :adapter => :sqlite,
    },
    :kirby => {
      :adapter => :kirby,
      :embedded => true
    },
      :memory => {
      :adapter => :memory,
    }  
    }

    def launch_og(config_type, classes)
      @managers ||= []
      @stores ||= []
      defaults = { :destroy => true, :evolve_schema => :full, :name => 'test', :classes => classes }
      config = OgConfigs[config_type].merge defaults
      manager = Og.start(config)

      @managers << manager
      return manager
    end

    def store(manager)
      @stores << manager.get_store
      return @stores.last
    end

    def quick_setup(*classes)
      if classes.first.kind_of? Symbol
        @og = launch_og(classes.shift, classes)
      else
        @og = launch_og($og_config, classes)
      end
      
      Aspects.setup
      
      return store(@og)
    end

    def og_teardown(*stores)
      @stores.each do |store|
        store.close
      end
      @managers.each do |manager|
        manager.close_store
        manager.unmanage_classes
      end
    end
  end

  Og.create_schema = true
  Og.thread_safe = true

  Spec::Runner.configure do |configuration|
    configuration.include(OgSpec)
  end
end
