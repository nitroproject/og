require File.join(File.dirname(__FILE__), 'helper.rb')

describe "Setup of a new Og Manager" do
  
  before(:all) do
    MockManager=Struct.new :options, :manage_classes, :post_setup
  end
  

  it "should test_default" do
    manager = Og.start
    manager.should be_an_instance_of(Og::Manager)
    manager.options[:adapter].should == :sqlite
    manager.options[:name].should == 'data'
    manager.options[:called_by_og_setup].should == true
  end

  it "should test_mattrs_initialized" do
    manager = Og.start
    Og.manager.should == manager
    Og.thread_safe.should_not be_nil
  end  

  it "should test_missing_store" do
# gmosx: this test is not needed, Og catches and reports this
# error.
#   assert_raises(LoadError) { Og.start(:adapter => :missing) }
  end  

  it "should test_setup_default_store_plus_options" do
    manager = Og.start(:evolve_schema => true)
    manager.should be_an_instance_of(Og::Manager)
    manager.options[:adapter].should == :sqlite
    manager.options[:evolve_schema].should == true
  end

  it "should test_calls_manager_methods" do
    mock_manager = Struct.new(:options, :called) do 
      def manage_classes(*args)
        self.called = [:mc]
      end
      def post_setup
        self.called << :ps
      end
    end
    old = Og::Manager
    Og.const_set :Manager, mock_manager
    manager = Og.start
    manager.called.should == [:mc, :ps]
    Og.const_set :Manager, old
  end
end
