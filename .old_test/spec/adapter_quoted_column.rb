require File.join(File.dirname(__FILE__), 'helper.rb')

module TestAdapterQuotedColumn

describe "Columns Quoting by Adapter" do

  before do
    class World
      attr_accessor :char, String #reserved keyword
      has_many Player
    end  

    class Player
      attr_accessor :str, Fixnum 
      attr_accessor :int, Fixnum #reserved keyword
      attr_accessor :integer, Fixnum #reserved keyword
      belongs_to World
    end
    
    @store = quick_setup(World, Player)
  end

  it "should insert values with reserved keyword fields" do
  
    lambda do
      antonio         = Player.new
      antonio.str     = 100
      antonio.int     = 1
      antonio.integer = 100
      antonio.save      
    end.should_not raise_error
      
  end
  
  it "should update values with reserved keyword fields" do
  
    proc do
      antonio     = Player.new
      antonio.str = 100
      antonio.int = 10
      antonio.save
      antonio.int = 1000
      antonio.save
    end.should_not raise_error
  
  end
  
  it "should run properly" do
  
    proc do
      world           = World.new
      world.char      = 'Mars'
      antonio         = Player.new
      antonio.str     = 1
      antonio.int     = 100
      antonio.integer = 155
      world.players << antonio
      world.save
      antonio.int = 1
      antonio.save
    end.should_not raise_error
  
  end
  
  after do
    og_teardown(@store)
  end
end

end
