require File.join(File.dirname(__FILE__), "..", "..", "helper.rb")

require "og/util/ann_attr"

class MockClass
  is Anise
  attr_accessor :name, String
  attr_accessor :hits, Fixnum
  attr_accessor :create_time, Time
end

# Lets test.

describe "ann_attr utilities collection" do

  before(:all) do
    @og = OgSpecHelper.setup
    @m = MockClass.new
  end
  
  it "defines force methods for all kinds of classes" do
    @m.__force_hits("12")
    @m.hits.should == 12
    @m.hits.class.should == Fixnum

    @m.__force_create_time(Time.now.to_s)
    @m.create_time.class.should == Time
  end
  
end
