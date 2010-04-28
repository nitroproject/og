# Various helpers to make testing easier and more intuitive.

# Show full debug info?

$DBG = true

# Select the adapter to test:
#
# * :mysql
# * :psql
# * :sqlite
# * :dbi_mysql

OG_ADAPTER = :mysql

# Configuration options for the different adapters.

OG_CONFIG = { 
  :mysql => {
    :adapter => :mysql,
    :user => "root",
    :password => ENV["DB_PASSWORD"]
  },
  :psql => {
    :adapter => :postgresql,
    :user => "postgres",
    :password => ENV["DB_PASSWORD"]
  },
  :sqlite => {
    :adapter => :sqlite,
  },
  :dbi_mysql => {
  :dbi_driver => :mysql,
  :user => "root",
  :password => ENV["DB_PASSWORD"]
  },
  :dbi_sqlite => {
  :dbi_driver => :sqlite
  }
}

# --------------------------------------------------------------

require "spec"

begin
  require "rubygems"
rescue LoadError => ex
  # drink it!
end

require "og"

module OgSpecHelper
  
  class << self

  # Start an Og instance.
    
  def setup(adapter = OG_ADAPTER)
    Og.create_schema = true
    
    defaults = { 
      :destroy => true, 
      :evolve_schema => :full, 
      :name => "test"
    }

    config = OG_CONFIG[adapter].merge(defaults)

    manager = Og.connect(config)

    Aspects.setup

    return manager
  end
  alias_method :start, :setup
    
  # Stop an Og instance.
  
  def stop
  end

  end

end

#module Spec::DSL::BehaviourEval::ModuleMethods
#  alias :should :it
#end

Logger.get.level = Logger::FATAL unless $DBG

