require File.join(File.dirname(__FILE__), '..', 'helper.rb')

require 'og/model/revisable'

describe "Revisable Model" do

  before(:each) do
    class OgRevisableArticle
      is Revisable
      attr_accessor :body, String, :revisable => true
      attr_accessor :title, String

      def initialize(t, b)
        @title, @body = t, b
      end
    end
    
    @store = quick_setup(OgRevisableArticle, OgRevisableArticle::Revision)
  end

  it "should be revisable and work" do
    a =OgRevisableArticle.create('hello', 'world')
    a.revise do |a|
      a.body = 'wow!'
    end
    a.revise do |a|
      a.body = 'nice'
    end
    a.revise do |a|
      a.body = 'it'
    end
    
    a.revisions.count.should == 3
    
    rev = a.get_revision(2)
    rev.body.should == 'wow!'
    
    a.rollback(2)
    a.body.should == 'wow!'
    
    a.rollback(1)
    a.body.should == 'world'
    
    a.rollback(3)
    a.body.should == 'nice'

    a.revisions.count.should == 6
    
    a.revise do |a|
      a.title = 'kicks'
      a.body = 'ass'
    end

    a.revisions.count.should == 7
    
    # The automatically generated class.
    
    OgRevisableArticle::Revision.count.should == 7
  end

  after do
    og_teardown(@store)
  end

end
