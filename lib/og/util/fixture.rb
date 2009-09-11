#require 'facets/kernel/constant'
require 'facets/settings'

require 'nitro/template'

require "og/util/inflect"

module Og 

# A collection of helper methods.
#--
# WARNING: This probably does not work, needs to be updated.
#++

class Fixtures

  # The directory where the fixtures are located.
  
  setting :root_dir, :default => 'test/fixture', :doc => 'The directory where the fixtures are located'

  @fixtures = {}
  
  class << self
  
    def load(*classes)
      for klass in classes
        f = Fixture.new(klass).load
        @fixtures[f.name] = f
      end
    end  

    def [](klass)
      @fixtures[klass]
    end
    
    def []=(klass, fixture)
      @fixtures[klass] = fixture
    end
    
    def method_missing(sym)
      if f = @fixtures[sym.to_s]
        return f
      end
      super
    end  
  end
end

# Fixtures is a fancy word for ‘sample data’. Fixtures allow you 
# to populate your database with predefined data. Fixtures are
# typically used during testing or when providing initial data
# (bootstrap data) for a live application.
#
# A Fixture is a collection (Hash) of objects.

class Fixture < Hash

  # The name of this Fixture.
  
  attr_accessor :name
  
  # The class that the Fixtures refer to.
  
  attr_accessor :klass

  # Used to keep the order.
  
  attr_accessor :objects
  
  def initialize(klass, options = { } )
    @klass = klass
    @name = class_to_name(klass)
    @objects = []    
    load(options[:root_dir] || options[:root] || Fixtures.root_dir)
  end

  def load(root_dir = Fixtures.root_dir)
    raise("The fixture root directory '#{root_dir}' doesn't exits") unless File.exist?(root_dir)

    if path = "#{root_dir}/#{@name}.yml" and File.exist?(path)
      parse_yaml(path)
    end

    if path = "#{root_dir}/#{@name}.yaml" and File.exist?(path)
      parse_yaml(path)
    end
    
    if path = "#{root_dir}/#{@name}.csv" and File.exist?(path)
      parse_csv(path)
    end
    
    return self
  end
  
  # Parse a fixture file in YAML format.
  
  def parse_yaml(path)
    require 'yaml'

    str = Nitro::Template.new.render(File.read(path))
    
    if yaml = YAML::load(str)
      for name, data in yaml
        self[name] = instantiate(data)
      end
    end

    # sort the objects.
        
    str.scan(/^(\w*?):$/).each do |key|
      @objects << self[key.to_s]
    end
  end

  # Parse a fixture file in CSV format. Many RDBM systems and 
  # Spreadsheets can export to CVS, so this is a rather useful
  # format.
  
  def parse_csv(path)
    require 'csv'

    str = Nitro::Template.new.render(File.read(path))
    
    reader = CSV::Reader.create(str)
    header = reader.shift

    reader.each_with_index do |row, i|
      data = {}
      row.each_with_index do |cell, j| 
        data[header[j].to_s.strip] = cell.to_s.strip 
      end
      self["#{@name}_#{i+1}"] = obj = instantiate(data)
      @objects << obj
    end
  end
  
private    

  # Instantiate an actual object from the Fixture data.
    
  def instantiate(data)
    obj = @klass.allocate
    
    for key, value in data
      obj.instance_variable_set("@#{key}", value)
    end
    
    return obj
  end

  def class_to_name(klass)
    klass.to_s.demodulize.underscore
  end  
  
end

end
