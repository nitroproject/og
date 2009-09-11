require File.join(File.dirname(__FILE__), 'helper.rb')

module OgPolymorphic
  include Og

describe "Accumulating has_many relationship objects in collection" do
  
  before do
    class Foo
      attr_accessor :name, String
      has_many Bar
    end

    class Bar
      attr_accessor :name, String
      belongs_to Foo
      has_many Foobar
    end

    class Foobar
      attr_accessor :name, String
      belongs_to Bar
    end
    
    @store = quick_setup(Foo, Bar, Foobar)
  end
  

  it "should accumulate objects" do
    2.times do |i|
      foo = Foo.new
      foo.name = "foo #{i}"
      foo.save
    end

    Foo.all.size.should == 2

    3.times do |i|
      bar = Bar.new
      bar.name = "bar #{i}"
      bar.save
    end

    Bar.all.size.should == 3

    6.times do |i|
      foobar = Foobar.new
      foobar.name = "foobar #{i}"
      foobar.save
    end

    Foobar.all.size.should == 6

    foo1 = Foo[1]
    bar1 = Bar[1]
    bar1.add_foobar Foobar[1]
    bar1.add_foobar Foobar[2]
    bar1.add_foobar Foobar[3]
    bar1.save
    foo1.add_bar bar1
    foo1.save

    foo2 = Foo[2]
    bar2 = Bar[2]
    bar3 = Bar[3]
    bar2.add_foobar Foobar[4]
    bar3.add_foobar Foobar[5]
    bar3.add_foobar Foobar[6]
    bar2.save
    bar3.save
    foo2.add_bar bar2
    foo2.add_bar bar3
    foo2.save

    # this work...

    ar = Array.new
    foo1.bars.each do |ii|
      ar.push(ii.foobars)
    end
    ar.flatten!
    ar.size

    foo_foobars = foo1.bars.foobars
    foo_foobars.size.should == 3
    foo_foobars.first.class.should == Foobar
  end
  
  after do
    og_teardown(@store)
  end

end

end
