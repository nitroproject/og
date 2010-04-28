#require "facets/time/stamp"

module Og::Mixin

# Adds timestamping functionality.
#--
# TODO: add an initialize method that inits times 
# before saving?
#++

module Timestamped
  include Anise

  attr_accessor :create_time, Time, :control => :none
  attr_accessor :update_time, Time, :control => :none
  attr_accessor :access_time, Time, :control => :none

  before :og_insert do
    @update_time = @create_time ||= Time.now
  end

  before :og_update do
    @update_time = Time.now
  end

  def updated!
    self.instance_attribute_set(:update_time, Time.now)
  end
  
  def touch!
    self.instance_attribute_set(:access_time, Time.now)
  end
  
  # Order the base class by create_time (useful common case).
  
  def self.included(base)
    base.order("create_time DESC")
  end
end

# Adds simple timestamping functionality on create.
# Only the create_time field is added, to add 
# create/update/access fields use the normal timestamped
# module.

module TimestampedOnCreate
  include Anise

  attr_accessor :create_time, Time, :control => :none

  before :og_insert do 
    @create_time = Time.now
  end
  
  # Order the base class by create_time (useful common case).
  
  def self.included(base)
    base.order("create_time DESC")
  end  
end

end
