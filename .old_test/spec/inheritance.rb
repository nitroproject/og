require File.join(File.dirname(__FILE__), 'helper.rb')


class Document
  is Og::Mixin::SingleTableInherited
  
  attr_accessor :title, String
  
  def initialize(title)
    @title = title
  end    
end

class Article < Document
  attr_accessor :body, String
  
  def initialize(title, body)
    @title, @body = title, body
  end
end

class Photo < Document
  attr_accessor :url, String
  
  def initialize(title, url)
    @title, @url = title, url
  end    
end

class Car
  attr_accessor :name, String
  belongs_to :admin
end

class User
  is Og::Mixin::SingleTableInherited
  
  attr_accessor :login, String
  many_to_many Car
end

class Admin < User
  attr_accessor :password, String
  #has_one Car
end

describe "Og Inheritance rules" do
  
  before(:each) do
    @store = quick_setup(Document, Article, Document, Photo, Car, User, Admin)
  end
  
  after(:each) do
    og_teardown(@store)
  end


  it "should do stuff" do
    Photo.superclass.should == Document
    descendents = Document.descendents
    descendents.size.should == 2
    descendents.include?(Photo).should == true
    descendents.include?(Article).should == true
    
    Document.schema_inheritance?.should == true

    # propagate schema_inheritance flag.
    
    Photo.schema_inheritance?.should == true
  
    # subclasses reuse the same table.
    
    Photo.table.should == Document.table
    
    doc = Document.create('doc1')
    Photo.create('photo1', 'http:/www.gmosx.com/photo/1')
    Photo.create('photo2', 'http:/www.gmosx.com/photo/2')
    Article.create('art1', 'here comes the body')
    Article.create('art2', 'this is cool')
    Article.create('art3', 'this is cooler')
    
    docs = Document.all

    docs.size.should == 6
    docs[4].title.should == 'art2'

    docs[0].class.should == Document
    docs[1].class.should == Photo
    docs[4].class.should == Article
    
    photos = Photo.all
    
    photos.size.should == 2
    photos[1].title.should == 'photo2'
    photos[0].url.should == 'http:/www.gmosx.com/photo/1'
    
    articles = Article.all
    
    articles.size.should == 3
    articles[2].title.should == 'art3'
    
    articles = Article.all(:limit => 2)
    articles.size.should == 2

    # Bug report.
    # This happens when creating a has_one Car in Admin, which is wrong 
    # because it overrides the joins_many from User.
    #Admin.create
    #Admin.create.car
  end
end


class Project
  is Og::Mixin::SingleTableInherited
  
  attr_accessor :koko, String
end

class FProject < Project
  attr_accessor :haha, String
end

class DProject < Project
  attr_accessor :kaka, String
end

describe "Og additional Inheritance rules" do
  
  before(:each) do
    @store = quick_setup(Project, FProject, DProject)
  end
  
  after(:each) do
    og_teardown(@store)
  end

  it "should not raise when creating" do
    proc do
      Project.create
      FProject.create
      DProject.create
    end.should_not raise_error
  end
end

