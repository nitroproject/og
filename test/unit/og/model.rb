require File.join(File.dirname(__FILE__), "..", "helper.rb")

describe "a model class" do

  before do
    class Generic
      is Og::Model
      attr_accessor :name, String
    end

    @og = OgSpecHelper.setup    
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
    end.should raise_error(Og::Deleted)
  end
end

