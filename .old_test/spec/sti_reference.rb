require File.join(File.dirname(__FILE__), 'helper.rb')

require 'og/model/sti'

describe "The references of a STI subclass" do
  before(:each) do
    class Root1
      is Og::Mixin::SingleTableInherited
    end

    class Child1 < Root1
      has_one :two, Child2
    end

    class Root2
      is Og::Mixin::SingleTableInherited
    end

    class Child2 < Root2
      attr_accessor :splat, String
      belongs_to :one, Child1
    end
    @store = quick_setup(Root1, Child1, Root2, Child2)
    @c1 = Child1.new
    @c2 = Child2.new
  end

  after(:each) do
    og_teardown
  end

  it "should add column for foreign key" do
    fields = @store.__send__(:fields_for_class, Root1)
    field_names = fields.map {|f| f.match(/"([^']*)" .*/)[1] }

    field_names.should include("two_oid")
  end

  it "should all be manageable" do
    @og.manageable?(Child1).should equal(true)
    @og.manageable?(Child2).should equal(true)
  end

  it "should persist across storage" do
    @c1.should_not be_nil
    @c2.should_not be_nil
    
    @c1.two = @c2
    @c1.save
    
    @c1.pk.should_not be_nil
    @store.query("SELECT ogtype FROM ogroot1 WHERE oid=#{@c1.pk}").first_value.should_not be_nil
    c1 = Child1[@c1.oid]
    
    c1.should_not be_nil
    c1.two.oid.should eql(@c2.oid)
  end
end
