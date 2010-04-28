require "facets/class/descendents"
require "og/glue/interface"
require "facets/inheritor"

# Support for simple Aspect Oriented Programming (AOP).
#
# The 'before' and 'after' methods wrap another method or a 
# block of code arround the target method.
#
# before :save do 
#   @time = Time.now
# end
# before :insert, :call => :timestamp
# before :read, :create, :call => :check_user_login
# after :read, do 
#   puts "Article hit"
# end
# before instance_methods, :call => :log
#
# The :call => :advice version is slightly faster, but the 
# default block notation is more elegant. The aspects are s
# inherited. You can define aspects before the target methods
# are defined.
#
# If no target methods are provided, apply the advice
# to all localy defined public methods. For example:
#
# before(:call => :try_login)
# before do
#   @time = Time.now
# end
#
# The Aspects module is included by default in all modules.
#
# Check this page for more details on the method aliasing trick:
# http://zimbatm.oree.ch/2006/12/25/various-method-aliasing-methods-in-ruby
#
# author: George Moschovitis (http://gmosx.com)
#--
# TODO: add some synchronization code.
#++

module Aspects

  # An aspect advice.  

  class Advice # :nodoc: all
    attr_accessor :handler, :targets, :advice 
    # Methods that are wrapped with this advice, used to avoid
    # multiple wrapping.
    attr_accessor :wrapped
    
    def initialize(handler, targets, advice)
      @handler, @targets, @advice = handler, targets, advice
      @wrapped = []
    end
    
    def wrapped?(key)
      @wrapped.include?(key)
    end

    # Wrap the given method of the given class with the 
    # advice.
    
    def wrap(klass, m)
      if klass.instance_interface.include? m.to_s
        key = "#{klass}.#{m}"
        unless wrapped.include? key
          klass.send(@handler, m, @advice)
          wrapped << key
        end
      end
    end
  end
  
  # Insert the advice before the method.
 
  def before(*args, &block)
    targets, advice, options = Aspects.resolve(self, args, block)
    advices! << Aspects::Advice.new(:before_method, targets, advice)
    Aspects.apply(self) unless $STATIC_ASPECTS
    return self
  end
  alias_method :pre, :before

  # Insert the advice after the method. Works exactly like
  # #before.
 
  def after(*args, &block)
    targets, advice, options = Aspects.resolve(self, args, block)
    advices! << Aspects::Advice.new(:after_method, targets, advice)
    Aspects.apply(self) unless $STATIC_ASPECTS
    return self
  end
  alias_method :post, :after

  def before_method(meth, advice) # :nodoc:
    old_method = instance_method(meth)
    args = Aspects.resolve_args(old_method)
    
    if advice.is_a? Proc 
      eval %{
      define_method(meth) do |#{args}|
        instance_eval(&advice)
        old_method.bind(self).call(#{args})
      end
      }
    else
      eval %{
      define_method(meth) do |#{args}|
        send(advice)
        old_method.bind(self).call(#{args})
      end
      }
    end
  end

  def after_method(meth, advice) # :nodoc:
    old_method = instance_method(meth)
    args = Aspects.resolve_args(old_method)

    if advice.is_a? Proc 
      eval %{
      define_method(meth) do |#{args}|
        old_method.bind(self).call(#{args})
        instance_eval(&advice)
      end
      }
    else
      eval %{
      define_method(meth) do |#{args}|
        old_method.bind(self).call(#{args})
        send(advice)
      end
      }
    end
  end

  class << self

    # Apply all aspects to all classes. In some cases,
    # you have to manually call this method.
    
    def setup
      ObjectSpace.each_object(Class) do |c|
        apply(c)
      end
    end
    
    # Apply aspects to the given class.
    
    def apply(klass)
      $ASPECTS_WRAPPING_METHOD = true

      return unless klass.respond_to? :advices

      for a in klass.advices
        if a.targets == :LOCAL_METHODS
          meths = klass.instance_interface(:local, :public)
        else
          meths = a.targets
        end
        for m in meths
          a.wrap(klass, m)
        end
      end
      
      $ASPECTS_WRAPPING_METHOD = false
    end

    #--
    # Internal utility method, factors out common code.
    #++
    
    def resolve(klass, args, block) # :nodoc:
      advice = nil
      
      if args.last.is_a? Hash
        options = args.pop
        advice = options[:call] || options[:advice] 
      end

      unless klass.respond_to? :advices
        klass.inheritor(:advices, [], :+)
      end
        
      advice = block if block
       
      targets = [args].flatten
      
      # If no target methods are provided, apply the advice
      # to all localy defined public methods.
        
      if targets.empty?
        targets = :LOCAL_METHODS
      end
      
      return targets, advice, options 
    end

    #--
    # Internal utility. Resolves the arguments to the original
    # method (useful to preserve arity).
    #++
    
    def resolve_args(target)
      if (ar = target.arity) > 0
        args = []
        ar.times do |i|
          args << "param#{i}"
        end
        args = args.join(", ")
      elsif ar == 0
        args = ""
      else
        args = "*args"
      end

      return args
    end
    
  end # self
  
end

unless $STATIC_ASPECTS

class Object # :nodoc: all
  #--
  # Apply aspects to new methods.
  # FIXME: make this thread safe.
  #++
 
  def self.method_added(name)
    super
    # Ignore method_added callbacks for the wrapping process.
    return if $ASPECTS_WRAPPING_METHOD
    Aspects.apply(self)
  end
end

end

#--
# Add AOP support to all modules.
#++

class Module
  include Aspects
end
