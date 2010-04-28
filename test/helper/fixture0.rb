class User 
  is Og::Model

  attr_accessor :name, String, :sql => "VARCHAR(20)"
  attr_accessor :age, Fixnum
  attr_accessor :email, String
  
  has_many :articles
end

class Article
  is Og::Model

  attr_accessor :title, String
  property :body, String # alias for attr_accessor

  belongs_to :user
end

#module Spec::DSL::BehaviourEval::ModuleMethods
#end

