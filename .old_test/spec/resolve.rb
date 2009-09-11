require File.join(File.dirname(__FILE__), 'helper.rb')

class User
  attr_accessor :name, String
  attr_accessor :age, Fixnum
end

describe "Og Finder, Option Resolver" do
  
  before(:each) do
    @store = quick_setup(User)
  end
  
  after(:each) do
    og_teardown(@store)
  end

  it "should test_all" do
    User.create_with :name => 'George', :age => 30
    User.create_with :name => 'Gogo', :age => 10
    User.create_with :name => 'Stella'
    
    users = User.find [ "name LIKE ? AND age > ?", 'G%', 4 ]
    users.size.should == 2

    users = User.find [ "name LIKE ? AND age > ?", 'G%', 14 ]
    users.size.should == 1
    
    users = User.find [ "name LIKE ?", 'Stella' ]
    users.size.should == 1
    
    User.find "name LIKE 'G%' LIMIT 1"
    users.size.should == 1
  end
  
end
