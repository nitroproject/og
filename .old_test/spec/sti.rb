require File.join(File.dirname(__FILE__), 'helper.rb')

require 'og/store/sql'

describe "The classes in an STI tree" do

  before(:each) do

    class StiParent
      is Og::Mixin::SingleTableInherited

      attr_accessor :one, String
      attr_accessor :two, String
      #schema_inheritance
    end

    class StiChild < StiParent
      attr_accessor :three, String
    end
    @store = quick_setup(StiParent, StiChild)
  end

  after(:each) do
    og_teardown(@store)
  end

  it "should be managed by store" do
    @store.should_not be_nil
    @store.should be_kind_of(Og::Store)
  end

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
end

describe "In an example STI tree" do

  before(:each) do
    class Human
      is Og::Mixin::SingleTableInherited

      attr_accessor :name, String

      #schema_inheritance
      def initialize(name)
        @name = name
      end
    end

    class Parent < Human
      attr_accessor :job, String
    end

    class Child < Human
      attr_accessor :toys, String
    end

    @store = quick_setup(Human, Parent, Child)
    Parent.create('mom')
    Parent.create('dad')
    Child.create('son')
    @all = Human.all
  end

  after(:each) do
    og_teardown(@store)
  end

  it "the root should find all of the subclasses" do
    @all.size.should equal 3
  end
    
  it "the child classes should load as objects of their proper type" do
    parents = @all.select {|h| h.class == Parent }
    children = @all.select {|h| h.class == Child }
    
    parents.size.should equal 2
    children.size.should equal 1
    parents.map {|p| p.name }.sort.should eql %w[dad mom]
    children.map {|c| c.name }.sort.should eql %w[son]
  end

end
