require File.join(File.dirname(__FILE__), 'helper.rb')

describe "Text Primary Keys" do

  before(:each) do
    class TCTextPrimaryKey
      attr_accessor :name, String, :primary_key => true
      attr_accessor :age, Fixnum
      
      def initialize(name)
        @name = name
        @age = rand(100)
      end
    end

    @store = quick_setup(TCTextPrimaryKey)
  end

  after(:each) do
    og_teardown
  end

  it "insert model with text primary key" do

    # .insert method, raises atm
    object = TCTextPrimaryKey.new("Marvin").insert

    # .save method, does not work (as expected)
    object = TCTextPrimaryKey.new("Marvin").save
    TCTextPrimaryKey.count.should equal 1

  end

  it "searching for model with text primary key" do
    # this raised an error once, due to wrong type of pk escaping
    a = TCTextPrimaryKey["SomeThing"]
  end

end
