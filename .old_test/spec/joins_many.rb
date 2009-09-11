require File.join(File.dirname(__FILE__), 'helper.rb')

describe "A joins_many relation" do
  before(:each) do
    class Item
      attr_accessor :name, String

      joins_many Tag

      def to_s
        @name
      end
    end

    class Tag
      attr_accessor :name, String

      def to_s
        @name
      end
    end
    @og = quick_setup(Item, Tag)
    @conn = @og.conn

    (1..3).each do |n|
      t = Tag.new
      t.name = "Tag_#{n}"
      t.save
    end

  end

  after(:each) do
    og_teardown
  end
  
  it "should not interfere with model creation" do
    Tag.all.size.should equal(3)
    
    # see if i can get a tag back from th db
    Tag.find_by_name("Tag_1").should_not be_nil
  end

  it "should not raise exceptions when joining" do
    proc do
      i3 = Item.new
      i3.name = "Item_3"
      i3.save
      i3.add_tag(Tag.find_by_name("Tag_1"))
      i3.add_tag(Tag.find_by_name("Tag_2"))
      i3.save
    end.should_not raise_error
  end

  it "should create and manage a join table" do
    i1 = Item.new
    i1.name = "Item_1"
    i1.save
    i1.add_tag(Tag.find_by_name("Tag_1"))
    i1.add_tag(Tag.find_by_name("Tag_2"))
    i1.save

    i2 = Item.new
    i2.name = "Item_2"
    i2.save
    i2.add_tag(Tag.find_by_name("Tag_2"))
    i2.add_tag(Tag.find_by_name("Tag_3"))
    i2.save
    
    # count SQL, note that the join table will change when test class changes
    
    sql = 'SELECT count(*) FROM ogj_item_tag'
    
    # after inserting 2 tags into the each of the 2 items, 4 relations
    
    @conn.query(sql).first.first.to_i.should equal 4
    
    i1.delete(true)
    i2.delete(true)
    
    # after deleting the 2 items, the relations are invalid
    
    @conn.query(sql).first.first.to_i.should equal 0
  end

    # the following code is new and should not trigger an exception due to
    # existing items in the mapping table
    
end

describe "Multiple many-to-many relationships of the same class" do
  class Person
    attr_accessor :name, String
    
    many_to_many :friends, Person
    many_to_many :enemies, Person
    many_to_many :casual_acquaintances, Person

    def initialize(name)
      @name = name
    end
  end

  before(:each) do
    @store = quick_setup([Person])
    
    @george = Person.create('George')
    @judson = Person.create('Judson')
    @jonathan = Person.create('Jonathan')
    @trans = Person.create('Trans')
    @michael = Person.create('Michael')
    @brian = Person.create('Brian')
    
    @george.friends << @judson
    @george.friends.add(@trans)
    @george.enemies.push(@jonathan)
    @george.enemies << @michael
    @george.casual_acquaintances.add(@brian)
    
    # Although the relations *appear* correct in the current implementation, a
    # repopulation of the relations from the database fails this test as of now.
    @george.friends.reload
    @george.enemies.reload
    @george.casual_acquaintances.reload
  end

  after(:each) do
    Person.delete_all
    og_teardown(@store)
  end

  it "should have the correct number of objects" do
    @george.friends.size.should eql 2
    @george.enemies.size.should eql 2
    @george.casual_acquaintances.size.should eql 1
  end

  it "should contain the assigned objects" do
    @george.friends.should include(@judson)
    @george.friends.should include(@trans)
    @george.enemies.should include(@jonathan)
    @george.enemies.should include(@michael)
    @george.casual_acquaintances.should include(@brian)
  end
  
  it "should not contain unassigned objects" do
    @george.friends.should_not include(@jonathan)
    @george.friends.should_not include(@michael)
    @george.friends.should_not include(@brian)
    @george.enemies.should_not include(@judson)
    @george.enemies.should_not include(@trans)
    @george.enemies.should_not include(@brian)
    @george.casual_acquaintances.should_not include(@judson)
    @george.casual_acquaintances.should_not include(@trans)
    @george.casual_acquaintances.should_not include(@jonathan)
    @george.casual_acquaintances.should_not include(@michael)
  end
end

describe "A store with many-to-many relations" do
  before(:each) do
    class User
      attr_accessor :name, Og::VarChar(32), :unique => true

      def initialize(name = nil)
        @name = name
      end
    end

    class Category
      attr_accessor :title, Og::VarChar(32), :unique => true
      joins_many Article

      def initialize(title = nil)
        @title = title
      end
    end

    class Article
      attr_accessor :title, :body, String
      has_many :comments
      has_one :author, User
      refers_to :owner, User
      many_to_many Category

      def initialize(body = nil)
        @body = body
      end
    end

    class NewArticle < Article
      attr_accessor :more_text, String
    end

    class Comment
      attr_accessor :body, String
      attr_accessor :hits, Fixnum
      # lets define the relation name just for fun.
      belongs_to :article, Article
      belongs_to User
      after "$schema_after=1", :on => :og_create_schema

      order 'hits ASC'

      def initialize(body = nil, user = nil)
        @body = body
        @user = user
        @hits = 0
      end
    end

    class Bugger
      attr_accessor :name, String
      many_to_many Bugger
    end

    @store = quick_setup(User, Category, Article, NewArticle, Comment, Bugger)
    @category1 = Category.create('News')
    @category2 = Category.create('Sports')
    @article = Article.create('Hello')
    @article.categories << @category1
    @article.save
    @article.categories << @category2
    @article.save
  end

  after(:each) do
    og_teardown(@store)
  end

  it "should count relation members correctly" do
    @article.categories.size.should eql(2)
  end

  it "should count relations of found objects" do
    a = Article.find_by_body('Hello')
    a.categories.size.should eql(2)
    a.categories[0].title.should eql('News')
  end

  it "should count relations both ways" do
    c = Category.find_by_title('News')
    c.articles.size.should eql(1)
  end

  it "should keep track of relations of subclasses" do
    na = NewArticle.create('Bug')
    na.categories << @category1
    na.categories << @category2
    na.categories.size.should eql(2)
  end

  it "should allow a model class to join itself" do
    b1 = Bugger.create
    b2 = Bugger.create

    b1.buggers << b2

    b1.buggers.first.should_not be_nil
  end

  it "should allow null references" do
    proc do
      a = Article.create
      a.owner = nil
    end.should_not raise_error
  end
end
