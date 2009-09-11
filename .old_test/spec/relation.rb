require File.join(File.dirname(__FILE__), 'helper.rb')

class Dummer
  attr_accessor :dum, String
end

class User
  attr_accessor :name, String
  has_many Dummer
  has_many Article
  def initialize(name)
    @name = name
  end
end

class Article
  attr_accessor :body, String
  refers_to :active_user, User
  def initialize(body)
    @body = body
  end
end

describe "Og Relations" do
  
  before(:each) do
    @store = quick_setup(Dummer, User, Article)
  end
  
  after(:each) do
    og_teardown(@store)
  end

  it "should handle relations correctly" do
    # no-namespace case.
    rel = User.relation('dummers')
    rel.should_not be_nil
    rel.resolve_target
    rel.target_class.should == Dummer
  
    # namespace case.
    rel = User.relation('articles')
    rel.should_not be_nil
    rel.resolve_target
    rel.target_class.should == Article
    
    # bug: test the no belongs_to case in Article
  end

  it "should handle refers_to correctly" do
    # test refers_to accessor is correctly updated
    u = User.create("George")
    a = Article.create("Og is a good thing!")
    a.active_user.should be_nil

    a.active_user = u
    a.save!
    a.active_user_oid.should == u.oid

    u2 = User.create("Another user")
    a.active_user = u2
    a.save!
    a.active_user_oid.should == u2.oid

    # Note! Og doesn't automatically reload object referred by active_user
    # so this won't equal.
    a.active_user.object_id.should_not == u2.object_id

    # Even forced reload won't help here as it won't reload relations.
    a.reload
    a.active_user.object_id.should_not == u2.object_id

    # But forcing enchanted accessor to reload in refers_to.rb helps!
    a.active_user(true)
    # assert_equal(u2.object_id, a.active_user.object_id)
    # and just to be sure oids are still correct
    a.active_user_oid.should == u2.oid
  end
end
