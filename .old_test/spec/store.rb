require File.join(File.dirname(__FILE__), 'helper.rb')

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

describe "A store" do
  before(:each) do
    @store = quick_setup(User, Category, Article, NewArticle, Comment, Bugger)
    @article = Article.new('Article 1')
    @store.save(@article)
  end

  after(:each) do
    og_teardown(@store)
  end

  it "should convert types properly" do
    @store.quote(13).should eql('13')
    @store.quote(13.23).should eql('13.23')
    @store.quote("can't quote").should match(/'can[\\']'t quote'/)

    t = Time.now

    @store.parse_timestamp(@store.timestamp(t)).day.should eql(t.day)
    @store.parse_timestamp(@store.timestamp(t)).year.should eql(t.year)
    @store.parse_timestamp(@store.timestamp(t)).month.should eql(t.month)
    @store.parse_timestamp(@store.timestamp(t)).hour.should eql(t.hour)
    @store.parse_timestamp(@store.timestamp(t)).min.should eql(t.min)
    @store.parse_timestamp(@store.timestamp(t)).sec.should eql(t.sec)

    d = Date.new

    @store.parse_date(@store.date(d)).should eql(d)
  end

  it "should persist objects in the DB" do
    a2 = @store.load(1, Article)

    a2.body.should eql(@article.body)
  end

  it "should load objects with Store instance load()" do
    @article = Article.new('Article 1')
    @store.save(@article)

    @store.load(1, Article).body.should eql(@article.body)
  end

  it "should load objects with class load()" do
    Article.load(1).body.should eql(@article.body)
  end

  it "should load objects with class index" do
    Article[1].body.should eql(@article.body)
  end

  it "should perform selects based on SQL statements" do
    acs = Article.select("SELECT * FROM #{Article.table} WHERE oid=1")
    acs.first.body.should eql('Article 1')
  end

  it "should perform single row selects based on SQL statements" do
    acs = Article.select_one("SELECT * FROM #{Article.table} WHERE oid=1")
    acs.body.should eql('Article 1')
  end

  it "should perform single row selects based on a WHERE clause" do
    acs = Article.select_one("WHERE oid=1")
    acs.body.should eql('Article 1')
  end

  it "should find objects based on a :sql option" do
    acs = Article.find(:sql => "SELECT * FROM #{Article.table} WHERE oid=1")
    acs.first.body.should eql('Article 1')
  end

  it "should find objects based on a where clause (preferred)" do
    acs = Article.find(:sql => "WHERE oid=1")
    acs.first.body.should eql('Article 1')
  end

  it "should get single objects based on :condition option" do
    a0 = Article.one(:condition => "body='Article 1'")
    a0.body.should eql('Article 1')
  end

  it "should accurately report the existence of objects" do
    Article.exist?(1).should_not be_nil
    Article.exist?(999).should be_nil
  end

  it "should update objects and return the number of changed rows" do
    a = Article[1]
    a.body = 'Changed'
    a.save.should eql(1)
  end


  it "should create objects with a block" do
    a3 = Article.create do |a|
      a.title = 'Title 3'
      a.body = 'Article 3'
    end

    a0 = Article.one(:condition => "body='Article 3'")
    a0.body.should eql('Article 3')
  end

  it "should delete objects orthogonally from each other" do
    a2 = Article.new('Article 2')
    @store.save(a2)

    @store.load(1, Article).should_not be_nil
    @store.load(2, Article).should_not be_nil

    @store.delete(a2)

    @store.load(1, Article).should_not be_nil
    @store.load(2, Article).should be_nil
  end
end
