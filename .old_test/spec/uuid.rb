require File.join(File.dirname(__FILE__), 'helper.rb')

require "og/model/uuid"

describe "A class with a UUID primary key" do

  before(:each) do

    class Article
      include UUIDPrimaryKey
      attr_accessor :title, String
      attr_accessor :body, String
      
      def initialize(title, body)
        @title, @body = title, body
      end
    end

    @store = quick_setup(Article)
  end

  after(:each) do
    og_teardown(@store)
  end

  it "should should create an UUID on insert" do
    a = Article.new("Hello", "World")
    a.save!
    b = Article.new("Another", "One")
    b.save!
    a.oid.should_not == b.oid
  end

  
=begin
  it "should examine as schema inheritance" do
    StiParent.schema_inheritance?.should equal true
    StiChild.schema_inheritance?.should equal true
  end

  it "should pass on their fields to children" do
    fields = @store.__send__(:fields_for_class, StiChild)
    field_names = fields.map {|f| f.match(/"([^']*)" .*/)[1] }

    field_names.size.should equal 5
    field_names.should include("one")
    field_names.should include("two")
    field_names.should include("three")
    field_names.should include("ogtype")
  end

  it "should collect their children's fields" do
    fields = @store.__send__(:fields_for_class, StiParent)
    field_names = fields.map {|f| f.match(/"([^']*)" .*/)[1] }

    field_names.size.should equal 5
    field_names.should include("one")
    field_names.should include("two")
    field_names.should include("three")
    field_names.should include("ogtype")
  end
=end
end
