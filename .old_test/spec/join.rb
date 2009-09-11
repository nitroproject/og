require File.join(File.dirname(__FILE__), 'helper.rb')

class Category
  attr_accessor :title, String
  joins_many Article
  joins_many :third_join, Article, :table => :ogj_article_category_third
  joins_many :fourth_join, Article, :table => :ogj_article_category_fourth

  def initialize(title)
    @title = title
  end
end

class Article
  attr_accessor :title, String

  joins_many :first_join, Category, :through => ArticleToCategory
  joins_many :second_join, Category, :through => ArticleToCategory
  joins_many :third_join, Category, :table => :ogj_article_category_third
  joins_many :fourth_join, Category, :table => :ogj_article_category_fourth
  joins_many Category

  def initialize(title)
    @title = title
  end
end

class ArticleToCategory
  attr_accessor :rate, Float
  attr_accessor :hits, Fixnum
  has_one Article
  has_one Category
end

describe "Og Joins" do
  
  append_before(:all) do
    @store = quick_setup(Category, Article, ArticleToCategory)
    
    @c1 = Category.create('tech')
    @c2 = Category.create('funny')
    @c3 = Category.create('finance')

    @a = Article.create('a1')
    @a2 = Article.create('a2')
    @a3 = Article.create('a2')
  end
  
  
  it "should join classes" do
    # Put the categories into seperate relations

    @a.first_join.push(@c1, :hits =>3, :rate => 2.3) 
    @a.second_join.push(@c2, :rate => 1.2) 
    @a.third_join << @c1
    @a.fourth_join << @c2
    @a2.third_join << @c1
    @a3.fourth_join << @c1

    @a.categories << @c3
  end
  
  it "should join through, each relationship shoul appear correctly" do
    join = @a.first_join_join_data(@c1)
    join.rate.should == 2.3
    join.hits.should == 3

    join = @a.second_join_join_data(@c2)
    join.rate.should == 1.2
    join.hits.should == nil
  end


  # This feature should be available but I cannot think
  # of the best way to implement it right now.
  it "Should not show relationships where they should not."
    # join = @a.second_join_join_data(@c1)
    # assert_nil(join)

    # join = @a.first_join_join_data(@c2)
    # assert_nil(join)

    # join = @a.first_join_join_data(@c3)
    # assert_nil(join)


  it "should join through triple, relationships should appear correctly" do
    # Test each relationship appears where it should
    #"@c1 does not appear in third join relationship"
    (@a.third_join.map{|x|x.pk}.include?(@c1.pk)).should == true
    #"@c2 does not appear in fourth join relationship"
    (@a.fourth_join.include?(@c2)).should == true
    #"@c3 does not appear in categories (un-named) join relationship"
    (@a.categories.include?(@c3)).should == true
  end
  
  it "should also recognize the backwards relationships" do
    #"article does not appear in @c3 (reverse join broken)"
    (@c3.articles.include?(@a)).should == true
    #"@a2 does not appear in @c1.third_join (reverse join broken)"
    (@c1.third_join.include?(@a2)).should == true
    #"@a3 does not appear in @c1.fourth_join (reverse join broken)"
    (@c1.fourth_join.include?(@a3)).should == true
    #"@a3 appears in @c1.third_join (reverse join broken)"
    (!@c1.third_join.include?(@a3)).should == true
  end
    
  it "should not have relations which do not exist" do
    #"@c2 appears in third join relationship"
    (!@a.third_join.include?(@c2)).should == true
    #"@c3 appears in third join relationship"
    (!@a.third_join.include?(@c3)).should == true
    #"@c1 appears in fourth join relationship"
    (!@a.fourth_join.include?(@c1)).should == true
    #"@c3 appears in fourth join relationship"
    (!@a.fourth_join.include?(@c3)).should == true
    #"@c1 appears in categories (un-named) join relationship"
    (!@a.categories.include?(@c1)).should == true
    #"@c2 appears in categories (un-named) join relationship"
    (!@a.categories.include?(@c2)).should == true
  end
  
end
