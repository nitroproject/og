require File.join(File.dirname(__FILE__), "..", "..", "helper.rb")

require "og/model/orderable"

class Article
  is Og::Model
  is Orderable[]
  attr_accessor :body, String, :revisable => true
  attr_accessor :title, String

  def initialize(t, b)
    @title, @body = t, b
  end
end

describe "Additional Orderable Behaviour with Revisions" do
  
  before(:each) do
    @og = OgSpecHelper.setup
  end
  
  it "should be orderable with revisons" do
    a1 = Article.create("hello", "world")
    a2 = Article.create("another", "one")
    a3 = Article.create("great", "stuff")

    a1.position.should == 1
    a2.position.should == 2
    a3.position.should == 3

    a2.move_higher

    a1 = Article.find_by_title("hello")
    a2 = Article.find_by_title("another")

    a2.position.should == 1
    a1.position.should == 2

    a1.orderable_position = 32
    a1.position.should == 32
  end
  
end

