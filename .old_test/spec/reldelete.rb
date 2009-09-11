require File.join(File.dirname(__FILE__), 'helper.rb')

class Item
  attr_accessor :name, String

  has_one Category
  has_one Tag

  has_many Picture
  has_many :figures

  joins_many User
end

###### 
# Single
######

class Category
  attr_accessor :name, String

  belongs_to Item
end

class Tag
  attr_accessor :name, String

  refers_to Item
end

###### 
# Many
######

class Picture
  attr_accessor :name, String

  belongs_to Item
end

class Figure
  attr_accessor :name, String

  refers_to Item
end

###### 
# Many Many
######

class User
  attr_accessor :name, String

  many_to_many Item
end

describe "Og Relationship deletes" do

  before(:each) do
    @conn = @store = quick_setup(Item, Tag, Category, Picture, Figure, User)
    
    @i = Item.create_with(:name => 'Copter')
    @c = Category.create_with(:name => 'blabla')
    @t = Tag.create_with(:name => 'blabla')
    
    @p1 = Picture.create_with(:name => 'blabla1')
    @p2 = Picture.create_with(:name => 'blabla2')
    @f1 = Figure.create_with(:name => 'blabla1')
    @f2 = Figure.create_with(:name => 'blabla2')
    
    @u = User.create_with(:name => 'George')
    
    @i.category = @c; @c.save
    @i.tag = @t; @t.save
    
    @i.pictures << @p1
    @p2.item = @i
    
    @i.figures << @f1
    @f1.item = @i
    
    @i.add_user @u
  end
  
  after(:each) do
    og_teardown(@store)
  end
  
  it "should test_setup" do
    Item.count.should == 1
    Category.count.should == 1
    Tag.count.should == 1
    Picture.count.should == 2
    Figure.count.should == 2
    
    @i.tag.should == @t
    @i.category.should == @c
  end
  
  it "should test_relationship_intact" do
    @t.instance_variable_get('@item_oid').should == @i.oid
    @c.instance_variable_get('@item_oid').should == @i.oid
  end
  
  ###### 
  # Single
  ######
  
  it "should test_deletes_category" do
    @i.delete
    Category.count.should == 0
  end
  
  it "should test_no_deletes_tag" do
    @i.delete
    Tag.count.should == 1
  end
  
  ###### 
  # Many
  ######
  
  it "should test_deletes_picture" do
    @i.delete
    Picture.count.should == 0
  end
  
  it "should test_no_deletes_figure" do
    @i.delete
    Figure.count.should == 2
  end
  
  ##### 
  # Many Many
  #####
  
  #it "should test_deletes_rel_in_join_table" do
  #  @i.delete
  #  tbl = Og::JoinsMany::OgTempJ_ogj_tc_deletesrelationship_item_tc_deletesrelationship_user::OGTABLE
  #  n = @conn.query("SELECT COUNT(*) FROM #{tbl}").first_value.to_i
  #  
  #  n;.should == 0
  #end
  
  #####
  # Bug Reports
  #####
  
  it "should test_jo_category_foreign_key_na" do
    @i.category.should_not be_nil
    @i.category.item_oid.should == @i.pk
  end
  
end
