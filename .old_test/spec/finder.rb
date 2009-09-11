require File.join(File.dirname(__FILE__), 'helper.rb')

module OgFinder
  
describe "Og Finder" do
  
  setup do
    class User
      attr_accessor :name, String
      attr_accessor :age, Fixnum
      attr_accessor :father, String
    end
    
    @store = quick_setup(User)
  end

  it "should find Og objects" do
    User.find_by_name('tml').should be_nil
    User.find_by_name_and_age('tml', 3).should be_nil
    User.find_all_by_name_and_age('tml', 3).empty?.should == true
    User.find_all_by_name_and_age('tml', 3, :name_op => 'LIKE', :age_op => '>', :limit => 4).empty?.should == true
    
    User.find_or_create_by_name_and_age('tml', 3).should_not be_nil
    User.find_or_create_by_name_and_age('stella', 5).should_not be_nil
    User.find_or_create_by_name_and_age('tml', 3).should_not be_nil
    
    User.all.size.should == 2

    # Basic check that tml is just right.
    
    u = User.find_by_name('tml')
    u.name.should == 'tml'
    u.age.should == 3
    u.father.should be_nil

    # Block form initialization works.
    
    u2 = User.find_or_create_by_name_and_age('tommy', 9) {|x| x.father = 'jack' }
    u2.name.should == 'tommy'
    u2.age.should == 9
    u2.father.should == 'jack'

    # Doesn't create another object same object.
    
    u3 = User.find_or_create_by_name_and_age('tommy', 9) {|x| x.father = 'jack' }
    User.find_all_by_name('tommy').size.should == 1
  end
  
end

end
