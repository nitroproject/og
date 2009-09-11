require File.join(File.dirname(__FILE__), 'helper.rb')

module OgBuildCollection

describe "Og Building Collections" do
  
  setup do
    class Category
      attr_accessor :name, String
    end

    class User
      attr_accessor :name, String
      joins_many Category

      def initialize name
        @name = name
      end
    end
    
    @store = quick_setup(Category, User)
  end

  it "should build collections and save" do
    c1 = Category.create_with :name => 'one'
    c2 = Category.create_with :name => 'two'
    
    u = User.new 'gmosx'
    u.categories << c1
    u.categories << c2
    u.save
    
    g = User[1]
    g.categories.size.should == 2
  end
  
end

end
