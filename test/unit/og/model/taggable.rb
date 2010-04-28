require File.join(File.dirname(__FILE__), "..", "..", "helper.rb")

require "og"
require "og/model/taggable"

describe "Taggable#tags_to_names" do

  it "handles strings with whitespace" do
    tags = "real world, computers, geeks"
    tags = Taggable.tags_to_names(tags)
    tags.size.should == 3
    tags.first.should == "real world"
  end

  it "handles excessive (leading/trailing) whitespace" do
    tags = "  real     world, computers, geeks "
    tags = Taggable.tags_to_names(tags)
    tags.size.should == 3
    tags.first.should == "real world"
  end

end
