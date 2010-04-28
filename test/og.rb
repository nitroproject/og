require File.join(File.dirname(__FILE__), "helper.rb")

require "og"

require File.join(File.dirname(__FILE__), "helper", "fixture0.rb")

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
  
  it "initializes itself" do
    Og.manager.class.should == Og::Manager
  end
  
end
