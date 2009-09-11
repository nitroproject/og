require File.join(File.dirname(__FILE__), 'helper.rb')


describe "Og Type System" do

  it "varchar() should deliver good sql" do
    Og::VarChar(16).should == [String, {:sql_type => "VARCHAR(16)"}]
  end
  
end
