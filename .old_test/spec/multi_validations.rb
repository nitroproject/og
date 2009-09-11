require File.join(File.dirname(__FILE__), 'helper.rb')

describe "Behaviour of multiple validation calls" do
  
  before(:each) do
    class User
      attr_accessor :name, String

      validate_value :name
      validate_unique :name
    end
    
    class User
      validate_value :name
      validate_unique :name
    end
    
    @store = quick_setup(User)
  end
  
  after(:each) do
    og_teardown(@store)
  end

  it "should not stack validations on top of one another" do
    User.validation_rules.size.should == 2
  end
 
end
