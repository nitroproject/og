require 'test/unit'
require 'test/unit/assertions'

# FIXME This doesn;t exist in facets anymore. Where is it?
#require 'facets/ormsupport'

require 'glue'
require 'glue/fixture'
require 'og'
require 'og/test/assertions'

module Test::Unit
  
class TestCase

  # Include fixtures in this test case.
  #--
  # gmosx: this method should probably be moved to glue.
  #++
  
  def fixture(*classes)
  
    for klass in classes
      f = Glue::Fixture.new(klass)
      instance_variable_set "@#{klass.to_s.demodulize.underscore.pluralize}", f
      Glue::Fixtures[klass] = f
      
      # create variables for the fixture objects.
      
      for name, obj in f
        instance_variable_set "@#{name}", obj
      end      
    end

  end  
  
  # Include fixtures in this test case, and serialize them in 
  # the active Og store.
  
  def og_fixture(*classes)
    fixture(*classes)

    for klass in classes
      f = Glue::Fixtures[klass]

      for obj in f.objects
        obj.save
      end
    end    
  end

end

end
