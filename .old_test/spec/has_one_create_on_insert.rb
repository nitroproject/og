require File.join(File.dirname(__FILE__), 'helper.rb')

module OgHasOneCreateOnInsert

describe "Og has_one with :create_on_insert" do

  setup do
    class User
      attr_accessor :name, String
      has_one :profile, :create_on_insert => true

      def initialize(name)
        @name = name
      end
    end

    class Profile
      attr_accessor :description, String
      belongs_to :user

      def initialize(description = 'Hello')
        @description = description
      end
    end
    
    @store = quick_setup(User, Profile)
  end


  it "should create a new foreign object on create" do
    u = User.new('gmosx')
    u.save # this should also create a profile.
        
    profile = u.profile
    profile.should_not be_nil
    profile.description.should == 'Hello'
  end
  
end

end
