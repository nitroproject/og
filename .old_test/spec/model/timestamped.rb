require File.join(File.dirname(__FILE__), '..', 'helper.rb')

require 'og/model/timestamped'

describe "Timestamped Model" do

  before(:each) do
    class OgTimestampedArticle 
      is Timestamped
      attr_accessor :body, String

      def initialize(body = nil)
        @body = body
      end
    end
    
    @store = quick_setup(OgTimestampedArticle)
  end

  it "should annotate Article with a create time" do
    a = OgTimestampedArticle.create('article')
    a.save
    
    a = OgTimestampedArticle[1]
    
    a.should respond_to(:create_time)
    a.create_time.should_not be_nil
  end

end
