require File.join(File.dirname(__FILE__), 'helper.rb')

describe "A unique validation on a model class" do
  before(:each) do
    class UniqueFramework
      attr_accessor :app_name, String
      attr_accessor :creator, String
      attr_accessor :index, Fixnum

      validate_unique :app_name
      validate_unique :index
    end

    quick_setup(UniqueFramework)
    @framework = UniqueFramework.new
    @app_name = 'Nitro'
    @framework.app_name = @app_name
    @framework.creator = 'gmosx'
    @framework.save
  end

  after(:each) do
    og_teardown
  end

  it "should not interfere with objects being saved" do
    @framework.should be_valid
    @framework.validation_errors.should be_empty
  end

  it "should allow already created object to be modified" do
    # if setup completes, then unique entries are already allowed.
    framework = UniqueFramework.find_all_by_app_name(@app_name)
    framework.size.should eql(1)
    framework[0].app_name.should eql(@app_name)
    framework[0].creator = "George Moschovitis"
    framework[0].should be_valid
    framework[0].validation_errors.size.should eql(0)
  end

  it "should allow unique fields to be updated" do
    framework = UniqueFramework.find_all_by_app_name(@app_name)
    framework.size.should eql(1)
    framework[0].app_name.should eql(@app_name)
    framework[0].app_name = "Rocket Science"
    framework[0].should be_valid
    framework[0].validation_errors.size.should eql(0)
  end

  it "should enforce unique-ness" do
    @dup = UniqueFramework.new
    @dup.app_name = @framework.app_name
    @dup.save
    @dup.should_not be_valid
    @dup.validation_errors.size.should be > 0
    @dup.validation_errors.should have_key(:app_name)
    @dup.validation_errors[:app_name].size.should eql(1)
    @dup.validation_errors[:app_name].first.should match(/.*not unique.*?/i)
  end

  it "should not resist null fields" do
    first = UniqueFramework.new
    first.index = nil
    first.index.should be_nil
    first.app_name = nil
    first.app_name.should be_nil
    first.save
    first.should be_valid

    second = UniqueFramework.new
    second.index = nil
    second.index.should be_nil
    second.app_name = nil
    second.app_name.should be_nil
    second.save
    second.should be_valid

    third = UniqueFramework.new
    third.index = 14
    third.save
    third.should be_valid

    fourth = UniqueFramework.new
    fourth.app_name = "different"
    fourth.save
    fourth.should be_valid
  end
end
  
describe "A value validation on a model class" do

  class ValueFramework
    attr_accessor :app_name, String
    attr_accessor :creator, String
    
    validate_value :creator
  end

  before(:each) do
    quick_setup(ValueFramework)
    @framework = ValueFramework.new
    @app_name = 'Nitro'
    @framework.app_name = @app_name
    @framework.creator = 'gmosx'
    @framework.save
  end

  after(:each) do
    og_teardown
  end

  it "should not interfere with objects being saved" do
    @framework.should be_valid
    @framework.validation_errors.should be_empty
  end

  it "should allow already created object to be modified" do
    # if setup completes, then unique entries are already allowed.
    framework = ValueFramework.find_all_by_app_name(@app_name)
    framework.size.should eql(1)
    framework[0].app_name.should eql(@app_name)
    framework[0].creator = "George Moschovitis"
    framework[0].should be_valid
    framework[0].validation_errors.size.should eql(0)
  end

  it "should enforce value" do
    dummy = ValueFramework.new
    dummy.save
    dummy.should_not be_valid

    dummy.creator = "Judson Lester"
    dummy.save
    dummy.should be_valid
  end
end

describe "A related validation for a model class" do
  class Uncle
    attr_accessor :name, String
    has_many :secrets, Secret
    validate_related :secrets
  end

  class Secret
    attr_accessor :name, String
    belongs_to :uncle, Uncle
  end

  before(:each) do
    quick_setup(Uncle, Secret)
    secret = Secret.new
    secret.save
    @uncle = Uncle.new
    @uncle.add_secret(secret)
    @uncle.save
  end

  after(:each) do
    og_teardown
  end

  it "should not interfere with objects being saved" do
    @uncle.should be_valid
    @uncle.validation_errors.should be_empty
  end

  it "should allow already created object to be modified" do
    # if setup completes, then unique entries are already allowed.
    uncle = Uncle.find
    uncle.size.should eql(1)
    uncle[0].name = "Murray"
    uncle[0].save
    uncle[0].should be_valid
    uncle[0].validation_errors.size.should eql(0)
  end

  it "should enforce valid relations" do
    great_uncle = Uncle.new
    great_uncle.add_secret(nil)
    great_uncle.save
    great_uncle.should_not be_valid
    secret = Secret.new
    great_uncle.add_secret(secret)
    great_uncle.save
    great_uncle.should be_valid
  end
end
