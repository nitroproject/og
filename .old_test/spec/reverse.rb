require File.join(File.dirname(__FILE__), 'helper.rb')

# 'testreverse' is a legacy database schema. Og's advanced
# reverse engineering features allows us to map any schema
# to our objects.

describe "Og Reverse engeneering DBs" do

  before(:each) do
    $store = quick_setup()
    
    class User
      attr_accessor :name, String, :field => :thename, :uniq => true
      attr_accessor :password, String
      attr_accessor :age, Fixnum, :field => :age3    
      has_many Comment, :foreign_field => :usr
      set_table :my_usrs
      set_primary_key :name, String

      def initialize(name, password, age)
        @name, @password, @age = name, password, age
      end
    end

    class Comment
      @@pk = $store.primary_key_type

      attr_accessor :cid, Fixnum, :sql => @@pk
      attr_accessor :body, String
      belongs_to User, :field => :usr
      set_table :my_comments
      set_primary_key :cid

      def initialize(body)
        @body = body
      end
    end
    
    begin
      $store.exec "drop table my_usrs"
      $store.exec "drop table my_comments"
    rescue Exception => e
      
    end
    
    $store.exec "create table my_usrs (thename VARCHAR(32) PRIMARY KEY, password TEXT, age3 INTEGER)"
    $store.exec "create table my_comments (cid #{$store.primary_key_type}, body TEXT, usr VARCHAR(32))"
    
    @store = quick_setup(User, Comment)
  end
  
  after(:each) do
    og_teardown(@store)
  end

  it "should handle reengeneered tables correctly" do
    User.table.should == 'my_usrs'
    Comment.table.should == 'my_comments'
    
    # .insert here because otherwise it will not save (pk already given)
    User.new('gmosx', 'nitro', 30).insert
    User.new('Helen', 'kontesa', 25).insert
    
    gmosx = User.find_by_name('gmosx')
    gmosx.name.should == 'gmosx'
    
    helen = User.find_all_by_age(25).first
    helen.name.should == 'Helen'
    
    c = Comment.new('hello')
    c.insert
    helen.comments << c
  
    helen.comments(:reload => true).size.should == 1
    helen.comments[0].body.should == 'hello'
  end
end
