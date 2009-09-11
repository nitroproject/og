
require File.join(File.dirname(__FILE__), 'helper.rb')

describe "A model class" do
  before(:each) do
    class Generic
      attr_accessor :name, String
    end

    @store = quick_setup(Generic)
  end

  after(:each) do
    og_teardown
  end

  it "should raise on reload after delete" do
    object = Generic.new
    object.name = "Marvin"
    object.save

    other_ref = Generic.find_one(:where => "name = 'Marvin'")
    other_ref.name.should eql("Marvin")
    other_ref.delete

    proc do
      object.reload
    end.should raise_error(Og::Deleted)#Something
  end
end
