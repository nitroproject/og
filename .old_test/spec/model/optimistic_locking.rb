require File.join(File.dirname(__FILE__), '..', 'helper.rb')

require 'og/model/optimistic_locking'

describe "Optimistic Locking Model" do
  
  before(:each) do
    class OgLockingArticle
      attr_accessor :body, String
      include Og::Mixin::Locking

      def initialize(body)
        @body = body
      end
    end
    
    @store = quick_setup(OgLockingArticle)
  end
  
  it "should" do
    OgLockingArticle.create('test')

    a = OgLockingArticle[1]
    
    b = OgLockingArticle[1]
    
    a.body = 'Changed'
    assert_nothing_raised do
      a.save
    end
    
    b.body = 'Ooops'
    assert_raise(Og::Mixin::StaleObjectError) do
      b.update
    end
    
    c = OgLockingArticle[1]
    a.body = 'Changed again'
    assert_nothing_raised do
      a.update
    end
  end
  
end
