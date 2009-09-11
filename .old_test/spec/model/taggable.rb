require File.join(File.dirname(__FILE__), '..', 'helper.rb')

require 'og/model/taggable'

module OgTaggable
  
  class Article
    attr_accessor :title, :body, String
    is Taggable

    def initialize(title = nil)
      @title = title
    end
  end

  class Second
    attr_accessor :haha, String
    is Taggable
  end
  
describe "Taggable Model" do

  before(:each) do
    @store = quick_setup(Tag, Article, Second)
  end
  
  def get_testobjects
    return @a1, @a2, @a3, @s1 if @a1
    
    @a1 = Article.create('Hello')
    @a1.tag('great gmosx sexy')
    @a1.save
    
    @a2 = Article.create('Other')
    @a2.tag('gmosx rain')
    @a2.save
    
    @a3 = Article.create('George')
    @a3.tag('phd name')
    @a3.save
    
    @s1 = Second.create
    @s1.tag('gmosx')
    @s1.save
  end
  
  it "should tag correctly" do
    a1, a2, a3, s1 = get_testobjects

    Tag.count.should == 6
    a1.tags.size.should == 3
    a1.tag_names.include?('great').should == true
    
    a1.tagged_with?('great').should == true
    
    a1.tagged_with?('photo').should == false
    
    res = Article.find_with_tags('great', 'gmosx')
    res.size.should == 1
    res[0].title.should == 'Hello'

    res = Article.find_with_tag('gmosx')
    res.size.should == 2
    res = res.map { |o| o.title }
    res.include?('Hello').should == true
    res.include?('Other').should == true

    res = Article.find_with_any_tag('great', 'gmosx', 'phd')
    res.size.should == 3

    a1.delete_all_tags
    a1.tags.size.should == 0
    
    Tag.count.should == 4
    
    Tag.all.each do |tag|
      n = case tag.name
      when 'rain', 'phd', 'name': 1
      when 'gmosx': 1
      else flunk tag.name + ' not expected'
      end
      
      tag.count.should == n
    end
    
    a = Second.create
    b = Second.create
    b.tag('hello world heh')
    a.tag('hello heh george gmosx')
    
    Second.find_with_tags('hello', 'heh').size.should == 2
    
=begin
    TODO:
    Article.fing_with_no_tag('gmosx')
    Article.find_by_tags('+name +gmosx -sexy')
    Article.find_by_tags(:with => '', :any => '', :no => '')
=end
  end
  
  it "should find Articles by tag" do
    a1, a2, a3, s1 = get_testobjects
    t = Tag.find_by_name('gmosx')
    
    t.should_not be_nil
    t.name.should == 'gmosx'
    
    a = Article.relations.find {|x| x.target_class == Tag }
    a.should_not be_nil
    a.owner_class.should == Article
    
    t.tagged.should == [a1, a2, s1]
  end

end

end
