require File.join(File.dirname(__FILE__), 'helper.rb')


class User
  attr_accessor :name, String, :uniq => true
  has_many Article
  
  def initialize(name)
    @name = name
  end
end

class Article
  attr_accessor :title, String
  belongs_to User
  
  def initialize(title)
    @title = title
  end
end

describe "Using multiple Stores at once" do
  
  before(:each) do
    @store = quick_setup(:psql, User)
    @store2 = quick_setup(:sqlite, Article)
  end
  
  after(:each) do
    og_teardown(@store)
    og_teardown(@store2)
  end
  
  it "should handle handle relations over multiple stores" do
    @store.class.should == Article.ogmanager.store.class
    @store2.class.should == User.ogmanager.store.class
    
    a1 = Article.create('hello')
    a2 = Article.create('world')
    
    u = User.create('gmosx')
    
    Article.count.should == 2
    
    u.articles << a1
    u.articles << a2
    
    gmosx = User.find_by_name('gmosx')
    gmosx.articles.size.should == 2
    gmosx.articles[0].title.should == 'hello'
  end
  
end
