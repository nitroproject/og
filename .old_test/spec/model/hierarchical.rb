require File.join(File.dirname(__FILE__), '..', 'helper.rb')

require 'og/model/hierarchical'

module OgHierarchical

describe "Hierarchical Model" do
  
  setup do
    class Comment
      attr_accessor :body, String
      attr_accessor :create_time, Time

      include NestedSets

      def initialize(body = nil)
        @body = body
        @create_time = Time.now
      end

      def to_s
        sprintf("%3d %3d %s", @lft, @rgt, @body)
      end
    end
    
    @store = quick_setup(Comment)
  end
  
  it "should add hierarchical data correctly" do
    root = Comment.create('root')
    c1 = Comment.new('1')
    root.add_comment c1
    c2 = Comment.new('1.1')
    c1.add_comment c2
    c3 = Comment.new('1.2')
    c1.add_comment c3
    c4 = Comment.new('1.1.1')
    c2.add_comment c4
    c5 = Comment.new('1.2.1')
    c3.add_comment c5
    c6 = Comment.new('1.1.1.1')
    c4.add_comment c6
    c7 = Comment.new('2')
    root.add_comment c7
    c8 = Comment.new('3')
    root.add_comment c8
    c9 = Comment.new('2.1')
    c7.add_comment c9

    c1.reload
    
=begin
    Comment.all(:order => "lft, rgt").each { |c|
      puts sprintf("%3d %3d %s", c.lft, c.rgt, c.body)
      # p c  
    }
    puts '--1'
    c1.comments(:order => "lft, rgt").each { |c| puts c.body }
    puts '--2'
    c1.full_comments(:order => "lft, rgt").each { |c| puts c.body }
    puts '--3'
    c1.direct_comments(:order => "lft, rgt").each { |c| puts c.body }
=end

    c1.full_comments.size.should == 6
    c1.comments.size.should == 5
    c1.direct_comments.size.should == 2
    
    c8.reload
    
    c8.parent.body.should == 'root'
  end
end

end
