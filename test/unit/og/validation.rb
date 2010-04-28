require File.join(File.dirname(__FILE__), "..", "helper.rb")

require "og/validation"

class User
  include Og::Mixin::Validation
  
  attr_accessor :name
  validate_confirmation :name
  
  attr_accessor :fullname
  validate_value :fullname
end

# Lets test.

describe "the validation system" do

  it "validates confirmations" do
    u = User.new
    u.name = "George"
    u.fullname = "George Moschovitis"
    u.instance_variable_set("@name_confirmation", "George")
    u.valid?.should == true
    u.instance_variable_set("@name_confirmation", "Stella")
    u.valid?.should == false
  end
  
  it "validation_errors returns nil for valid attributes" do
    u = User.new
    u.fullname = "George Moschovitis"
    u.valid?
    u.validation_errors[:fullname].should == nil
  end
  
end
