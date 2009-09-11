require File.join(File.dirname(__FILE__), 'helper.rb')

module OgAggrCalc
  include Og

describe "Aggregation Calculations" do

  before do
    class User
      attr_accessor :section, String
      attr_accessor :age, Fixnum
      is Timestamped

      def initialize(section, age)
        @section = section
        @age = age
      end    
    end
    
    @store = quick_setup(User)
  end

  it "should generally work" do
    User.create('a', 12)
    User.create('a', 16)
    User.create('d', 34)
    User.create('d', 33)
    User.create('c', 27)
    last = User.create('c', 31)
    
    User.count.should == 6
    User.minimum(:age).should == 12
    User.maximum(:age).should == 34
    User.max(:age).should == 34
    User.avg(:age).should == 25.5
    User.sum(:age).should == 153
    
    sums = User.sum(:age, :group => :section)
    sums.size.should == 3
    sums.include?(28).should == true
    sums.include?(58).should == true
    sums.include?(67).should == true
  end

  after do
    og_teardown(@store)
  end
  
end

end
