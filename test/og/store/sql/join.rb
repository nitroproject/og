require File.join(File.dirname(__FILE__), "..", "..", "..", "helper.rb")

require "og"

# Custom 'join' class.

class Friendship
  #is Og::Model
  is TimestampedOnCreate

  belongs_to :user, User
  belongs_to :user2, User # follows the standard naming convention for join classes, ie: ____2
  
  def initialize(u1, u2)
# FIXME: make this work:
# user, user2 = u1, u2
    @user_oid = u1.oid
    @user2_oid = u2.oid
  end
end

class User
  is Og::Model
  attr_accessor :name, String
  joins_many :friends, User, :through => Friendship
end

# Lets test.

describe "Sql stores" do

  def fixtures
    @gmosx = User.create_with :name => "gmosx"
    @renos = User.create_with :name => "renos"
    @stella = User.create_with :name => "stella"
    @nikos = User.create_with :name => "nikos"
  end

  before(:all) do
    @og = OgSpecHelper.setup    
    fixtures
  end
  
  it "allow allow joining 'through' a custom class" do
    @gmosx.friends << @stella
    @gmosx.friends.count.should == 1
    @gmosx.friends << @renos
    @gmosx.friends.include?(@renos).should == true
  end
  
  it "allows joining by instantiating the join class" do
    Friendship.create(@renos, @nikos)
    @renos.friends.include?(@nikos).should == true
  end
  
end
