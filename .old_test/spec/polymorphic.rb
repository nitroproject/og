require File.join(File.dirname(__FILE__), "helper.rb")


class Comment
  attr_accessor :body, String
  belongs_to :parent, :polymorphic => true

  def initialize(body)
    @body = body
  end
end

class Category
  attr_accessor :title, String
  has_many :children, :polymorphic => true

  def initialize(title)
    @title = title
  end
end

class Article
  attr_accessor :title, :body, String
  belongs_to :category
  has_many :comments
    
  def initialize(title, body)
    @title, @body = title, body
  end
end

describe "A base polymorphic object" do

  before(:each) do
    @store = quick_setup(Comment, Category, Article)
  end

  after(:each) do
    og_teardown(@store)
  end

  it "is Unmanageable" do
    Comment.ancestor?(Unmanageable).should equal(true)        
    Category.ancestor?(Unmanageable).should equal(true)        
  end

  it "automatically generates subclasses" do
    defined?(Article::Category).should == "constant"
    defined?(Article::Comment).should == "constant"
  end

  it "can look up target classes" do
    c = Article::Category.new("News")
    a = Article.new("Hello", "World")
    a.category = c
    a.save
    b = Article::Category[1]
    b.articles.first.title.should == "Hello"
  end

  it "can be looked up from target classes" do
    c = Article::Category.new("Misc")
    a = Article.new("Nitro", "rules")
    a.category = c
    a.save
    a = Article[1]
    a.category.title.should == "Misc"
    c = Article::Comment.new("It works")
    a.comments << c
    b = Article[1]
    b.comments.first.body.should == "It works"
  end

  it "does not keep the polymorphic relation" do
    Article::Category.relation(:children).should be_nil
  end
  
end
