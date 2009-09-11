require "fileutils"

#require "facets/kernel/constant"
#require "facets/kernel/assign_with"

module Og

# Add import/export functionality to the Og Manager.

class Manager
  
  # Dump Og managed objects to the filesystem.
  
  def dump(options = {})
    classes = options[:classes] || options[:class] || manageable_classes
    basedir = options[:basedir] || "ogdump"
    
    FileUtils.makedirs(basedir)
    
    for c in [ classes ].flatten      
      info "Dumping class '#{c}'"
      all = c.all.map { |obj| obj.properties_to_hash }
      File.open("#{basedir}/#{c}.yml", 'w') { |f| f << all.to_yaml }
    end
  end
  alias_method :export, :dump
  
  # Load Og managed objects from the filesystem. This method can apply
  # optional transformation rules in order to evolve a schema.
  
  def load(options = {})
    classes = options[:classes] || manageable_classes
    basedir = options[:basedir] || 'ogdump'
    rules = options[:rules] || rules[:evolution] || {}

    classes.each { |c| c.destroy if managed?(c) }
    unmanage_classes(classes)
    manage_classes
    
    for f in Dir["#{basedir}/*.yml"]
      all = YAML.load(File.read(f))
      
      unless all.empty?
        klass = f.split(/\/|\./)[1]
        
        info "Loading class '#{klass}'"
        
        if krules = rules[klass.to_sym]
          if krules[:self]
            # Class name changed.
            info "Renaming class '#{klass}' to '#{krules[:self]}'"
            klass = krules[:self]
          end
          
          info "Evolution transformation will be applied!"
        end      

        klass = constant(klass)
        
        for h in all
          obj = klass.allocate
          obj.assign_with(h)
          if krules
            krules.each do |old, new|
              obj.instance_variable_set "@#{new}", h[old]
            end
          end
          obj.insert
        end
      end
    end
  end
  alias_method :import, :load
  
end
  
end
