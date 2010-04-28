require File.join(File.dirname(__FILE__), "..", "..", "helper.rb")

$DBG = true

class Item
  is Og::Model

  attr_accessor :name, String

  has_many Tag
end

class Tag
  is Og::Model

  attr_accessor :name, String

  belongs_to Item
end

# Lets test.

describe "A Og Has-Many Relationship" do

  before(:all) do
    @og = OgSpecHelper.setup  
    @name = "George"
  end
  
  after(:each) do
    Item.delete_all
    Tag.delete_all
  end
  
  it "should concatenate more relations" do
    tag = Tag.create_with(:name => "Nitro")
    i = Item.create_with(:name => @name)

    i.tags << tag
    
    i.tags.size.should == 1
    i.tags.first.should == tag
  end

  it "should generate magic adders" do
    tag = Tag.create_with(:name => "Facets")
    i = Item.create_with(:name => @name)

    i.add_tag tag

    i.tags.size.should == 1
    i.tags.first.should == tag
  end

  it "should assign with tag" do
    tag = Tag.create_with(:name => "Nitro")
    
    tag.saved?.should_not be_nil
    
    i = Item.create_with(:name => @name, :tags => tag)

    i.saved?.should_not be_nil
    i.tags.first.should == tag
  end
  
  it "should assign_with_tags" do
    tags = [Tag.create_with(:name => "Glue"), Tag.create_with(:name => "Og")]
    i = Item.create_with(:name => @name, :tags => tags)

    i.tags.to_ary.should == tags
  end
  
  it "assign_with_collection" do
    coll = Og::HasManyCollection.new(
      Item,
      Tag,
      :add_tag,
      :remove_tag,
      :find_tags,
      :count_tags
    )
    i = Item.create_with(:name => @name, :tags => coll)

    i.instance_variable_get("@tags").should == coll
  end

end

