require File.join(File.dirname(__FILE__), "..", "..", "helper.rb")

require "og"

require File.join(File.dirname(__FILE__), "..", "..", "helper", "fixture0.rb")

# Lets test.

describe "the sql store" do

  def fixtures
    gmosx  = User.create_with :name => "gmosx", :age => 32, :email => "george.moschovitis@gmail.com"
    renos  = User.create_with :name => "renos", :age => 31
    stella = User.create_with :name => "stella"

    a = Article.new.populate(:title => "Hello", :body => "World")
    a.user = renos
    a.save 
  end

  before do
    @og = OgSpecHelper.setup    
    fixtures
  end
  
  it "allows querying specific columns" do
    u1 = User.one :select => [:age], :where => "name='gmosx'"
    u1.name.should == nil
    u1.age.should == 32
    u1.email.should == nil
    
    u2 = User.one :select => [:age, :email], :where => "name='gmosx'"
    u2.name.should == nil
    u2.age.should == 32
    u2.email.should == "george.moschovitis@gmail.com"
  end
  
end
