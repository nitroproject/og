module Og::Mixin

# Revision support for Og-managed classes.
#
# class Article
#   is Revisable
#   attr_accessor :body, String, :revisable => true
#   attr_accessor :title, String
# end
#
# Generates the Revision class:
#
# class Article::Revision
#
# article.revisions
#
# article.revise do |a|
#   a.title = 'hello'
#   a.body = 'world'
# end
#
# article.rollback(4)

module Revisable
  # The revision of the revisable object.
  
  attr_accessor :revision, Fixnum, :control => :none
  
  # This mixin is injected into the dynamically generated
  # Revision class. You can customize this in your application
  # to store extra fields per revision.
  
  module Mixin
    # The create time for the revision.
    
    attr_accessor :create_time, Time
  
    # Override to handle your options.
    
    def initialize obj, options = {}
      revision_from(obj)
      @create_time = Time.now
    end
    
    def revision_from obj
      for a in obj.class.serializable_attributes
        unless a == obj.class.primary_key
          instance_variable_set "@#{a}", obj.send(a.to_s)
        end
      end
    end
    
    def revision_to obj
      for a in obj.class.serializable_attributes
        unless a == obj.class.primary_key
          obj.instance_variable_set "@#{a}", self.send(a.to_s)
        end
      end
    end    
    alias_method :apply_to, :revision_to
  end

  def self.included base
    super
    
    base.module_eval %{
      class Revision < #{base}
        include Revisable::Mixin
        refers_to #{base}, :control => :none
      end
    }
    
    base.has_many :revisions, base::Revision, :control => :none
  end

  # Can accept options like owner or a comment.
  # You can specialize this in your app.
  
  def revise options = {}
    if self.revision.nil? 
      self.revision = 1 
    else
      self.revision += 1
    end
    self.revisions << self.class::Revision.new(self, options)
    yield(self) if block_given?
    self.save
  end
  alias_method :revise!, :revise

  # Rollback to an older revision.
  
  def rollback rev, options = {}
    self.revise(options) { |obj| get_revision(rev).apply_to(obj) }
  end

  # Return a revision.
 
  def get_revision rev
    return self if rev.to_i == self.revision
    self.revisions.find_one(:condition => "revision=#{Og.quote(rev)}")
  end

  # Return the last revision.
  
  def last_revision
    self.revisions(:order => 'revision DESC', :limit => 1).first
  end

  # The number of revisions.
  
  def revision_count
    self.revisions.count
  end
  alias_method :revisions_count, :revision_count
  
end

end
