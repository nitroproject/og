require File.join(File.dirname(__FILE__), 'helper.rb')


class Item
  attr_accessor :quantity, Fixnum
  attr_accessor :unit_price, Float
  
  def initialize(quantity, unit_price)
    @quantity = quantity
    @unit_price = unit_price
  end
  
  def total_price
    @total_price.to_f
  end
end


describe "Og find(:select =>) Search" do

  before(:each) do
    @store = quick_setup(Item)
  end
  
  after(:each) do
    og_teardown(@store)
  end

  it "should test_all" do
    Item.create(2, 34.5)
    Item.create(5, 12.6)
    
    item = Item.one :select => 'quantity, quantity*unit_price as total_price', :condition => 'oid = 1'
  
    item.total_price.should be_close(2*34.5, 0.001)
    item.quantity.to_i.should == 2
  end
  
end
