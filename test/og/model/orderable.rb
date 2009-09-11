require File.join(File.dirname(__FILE__), "..", "..", "helper.rb")

require "og/model/orderable"
    
class Article
  attr_accessor :title, :body, String
  has_many :comments, Comment, :list => true, :order => "position DESC"

  def initialize(title = nil)
    @title = title
  end
end

class Comment 
  attr_accessor :body, String
  belongs_to :article

  # We have to set the parent before inserting the comment
  # for the scope to work!
  is Orderable #, :scope => :article

  def initialize(body = nil)
    @body = body
  end
end

class Playlist
  attr_accessor :name, String
  has_many :tracks
end

class Track
  attr_accessor :name, String
  is Orderable, :scope => :playlist

  belongs_to :playlist

  def initialize(name, playlist)
    @name = name
    self.playlist = playlist
  end
end

describe "Orderable Model" do
  before(:each) do
    @og = OgSpecHelper.setup
  end
  
  it "should order correctly" do
    a = Article.create("article")

    c1 = Comment.create("1")
    a.comments << c1
    c2 = Comment.create("2")
    a.comments << c2
    c3 = Comment.create("3")
    a.comments << c3

    c1.position.should == 1
    c2.position.should == 2
    c3.position.should == 3

    c3.move_higher

    c1.reload
    c2.reload
    c3.reload

    c1.position.should == 1
    c3.position.should == 2
    c2.position.should == 3

    c2.move_to_top

    c1.reload
    c2.reload
    c3.reload

    c2.position.should == 1
    c1.position.should == 2
    c3.position.should == 3

    c2.move_to_bottom

    c1.reload
    c2.reload
    c3.reload

    c1.position.should == 1
    c3.position.should == 2
    c2.position.should == 3

    c3.delete!

    c1.reload
    c2.reload

    c1.position.should == 1
    c2.position.should == 2

    c2.delete!

    c1.reload

    c1.position.should == 1

    c1.delete!
  end
  
  def track_list
    Track.find(:order => "position").map { |t| t.name }
  end

  it "should be orderable" do
    pl = Playlist.create

    %w{one two three four five six}.each do |n|
      Track.create(n, pl)
    end

    tr = Track.one(:condition => "position = 1")
    tr.should_not be_nil
    
    tr.move_to(4)
    tr.position.should == 4

    track_list.should == %w{two three four one five six}

    tr = Track.one(:condition => "position = 5")
    tr.move_to(3)
    tr.position.should == 3

    track_list.should == %w{two three five four one six}
  end
end

class Article
  is Orderable
  attr_accessor :body, String, :revisable => true
  attr_accessor :title, String

  def initialize(t, b)
    @title, @body = t, b
  end
end

describe "Additional Orderable Behaviour with Revisions" do
  
  before(:each) do
    @og = OgSpecHelper.setup
  end
  
  it "should be orderable with revisons" do
    a1 = Article.create("hello", "world")
    a2 = Article.create("another", "one")
    a3 = Article.create("great", "stuff")

    a1.position.should == 1
    a2.position.should == 2
    a3.position.should == 3

    a2.move_higher

    a1 = Article.find_by_title("hello")
    a2 = Article.find_by_title("another")

    a2.position.should == 1
    a1.position.should == 2

    a1.orderable_position = 32
    a1.position.should == 32
  end
  
end

