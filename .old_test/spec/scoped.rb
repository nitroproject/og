require File.join(File.dirname(__FILE__), 'helper.rb')

class User
  attr_accessor :name, String
  has_many :articles
end

class Article
  attr_accessor :hits, Fixnum
  belongs_to :user
end


describe "Og Scoped Search" do

  before(:each) do
    @store = quick_setup(User, Article)
  end
  
  after(:each) do
    og_teardown(@store)
  end

  it "should test_all" do
    u = User.create_with(:name => 'tml')
    a1 = Article.create_with :hits => 10
    a2 = Article.create_with :hits => 20
    u.articles << a1
    u.articles << a2
    
    u.articles.size.should == 2
    u.articles.find(:condition => 'hits > 15').size.should == 1
    u.articles.find(:condition => 'hits > 15').first.hits.should == 20
  end
  
end
