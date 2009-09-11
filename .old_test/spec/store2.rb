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

describe "A store with simple references" do
  before(:each) do
    @store = quick_setup(User, Category, Article, NewArticle, Comment, Bugger)
  end

  after(:each) do
    og_teardown(@store)
  end


  it "should follow simple references" do
    u = User.create('gmosx')
    a = Article.new('Article 1')
    a.owner = u
    a.author = u
    a.save

    a.author.name.should eql('gmosx')
    a.owner.name.should eql('gmosx')
  end

  it "should find objects by attribute" do
    u = User.create('gmosx')
    u.save
    
    u = User.find_by_name('gmosx')
    u.name.should eql('gmosx')
  end

  it "should allow relations to be inspected" do
    Comment.relations.size.should eql(2)
    Comment.relation(:article).class.should eql(Og::BelongsTo)
  end
end
