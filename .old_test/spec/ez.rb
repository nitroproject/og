require File.join(File.dirname(__FILE__), 'helper.rb')
  
module OgResolveOptions

describe "Og EZ Finder" do

  setup do
    class User
      attr_accessor :name, String
      attr_accessor :age, Fixnum
    end
    
    @store = quick_setup(User)
  end
  
  it "should find Og models via EZ" do
    User.create_with :name => 'George', :age => 14
    User.create_with :name => 'Renos', :age => 20
    User.create_with :name => 'Stella', :age => 23

    users = User.find do |user|
      user.age > 10
      user.any do 
        name == 'George'
        name == 'Stella'
      end
    end
    
    users.size.should == 2

    users = User.find { |user| user.age === [14, 23] }

    users.size.should == 2
  end
end

describe "Og EZ Finder triples" do
  
  setup do
    class Person
      attr_accessor :name, String
      attr_accessor :kids, Integer
      
      include Og::Mixin::SingleTableInherited
    end

    class Musician < Person
      attr_accessor :instruments, Array
    end

    class Plumber < Person
      attr_accessor :tools, Array
    end
    
    @store = quick_setup(Person, Musician, Plumber)
  end

  it "should op triple equals" do
    results = nil
    lambda do
      results = Musician.find {|m| m.kids === [3,4,5]}
    end.should_not raise_error
    results.empty?.should == true
  end
end

describe "Og EZ Finder non null" do
  
  setup do
    class Animal
      attr_accessor :mammal, TrueClass
    end
    
    @store = quick_setup(Animal)
  end
  
  it "should test for null" do
    2.times do
      animal = Animal.new
      animal.mammal = true
      animal.save

      animal = Animal.new
      animal.mammal = nil
      animal.save
    end

    rubyish = ezish = nil

    lambda do
      rubyish = {
        :true => Animal.all.select{|a| a.mammal}.map{|a| a.oid},
        :false => Animal.all.reject{|a| a.mammal}.map{|a| a.oid}
      }

      ezish = {
        :true => Animal.find{|animal| animal.mammal! == :null }.map{|a| a.oid},
        :false => Animal.find{|animal| animal.mammal == :null }.map{|a| a.oid}
      }
    end.should_not raise_error

    ezish[:true].should == rubyish[:true]
    ezish[:false].should == rubyish[:false]
  end
end

end
