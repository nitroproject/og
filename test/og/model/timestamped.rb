require File.join(File.dirname(__FILE__), "..", "..", "helper.rb")

require "og"

class Article
  is Timestamped
  attr_accessor :title, String
  
  def initialize(title)
    @title = title
  end
end

# Lets test.

describe "the timestamped mixin" do

  before(:all) do
    @og = OgSpecHelper.setup
  end
  
  it "automatically fills timestamp attributes when inserting models" do
    a = Article.new("Hello world")
    a.save!
    
    b = Article[1]
    b.create_time.class.should == Time
  end
  
end
