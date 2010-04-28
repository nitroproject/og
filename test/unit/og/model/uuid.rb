require File.join(File.dirname(__FILE__), "..", "..", "helper.rb")

require "og/model/uuid"

class Article
  is Og::Model
  is UUIDPrimaryKey

  attr_accessor :title, String
  attr_accessor :body, String
  
  def initialize(title, body)
    @title, @body = title, body
  end
end

# Lets test.

describe "A class with a UUID primary key" do

  before do
    @og = OgSpecHelper.setup  
  end

  it "should should create an UUID on insert" do
    a = Article.new("Hello", "World")
    a.save!
    b = Article.new("Another", "One")
    b.save!
    a.oid.should_not == b.oid
  end

end
