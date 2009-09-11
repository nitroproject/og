# A simple example to demonstrate the Og library.

require 'og'

# Full debug information.

$DBG = true

# A child class.

class Comment
  attr_accessor :body, String
  
  def initialize(body = nil)
    @body = body
  end
  
  def to_s
    return @body
  end
end

# = A Parent class.

class User
  attr_accessor :name, String, :uniq => true
  has_many :comments, UserComment
  
  def initialize(name = nil)
    @name = name
  end
  
  def to_s
    return @name
  end
end


# A parent class.

class Article
  attr_accessor :title, String
  attr_accessor :body, String

  # override the default O->R mapping

  attr_accessor :level, Fixnum, :sql => "smallint DEFAULT 1"

  # store a Ruby Hash in the Database. YAML
  # is used for serializing the attribute.
  # no need to define the class, but you can if you want.

  attr_accessor :options, Hash

  # exactly like the standard Ruby attr creates only the reader.

  prop :create_time, Time
  
  # define comment relation:

  has_many :comments, ArticleComment
  
  has_many :parts, Part

  # many to many relation.
  
  many_to_many Category
  
  # define author relation:

  belongs_to :author, User
  
  # this attribute is NOT stored in the db.

  attr_accessor :other_options
  
  # Managed object constructors with no args, take *args 
  # as parameter to allow for Mixin chaining.

  def initialize(title = nil, body = nil)
    @title, @body = title, body
    @create_time = Time.now
    @options = {}
    @other_options = {}
  end
  
  def to_s
    return "#@title: #@body"
  end
end

# A parent class.

class Category
  attr_accessor :title, String
  attr_accessor :body, String

  # define a 'many to many' relation.  

  many_to_many Article
  
  def initialize(title = nil)
    @title = title
  end
end


# Article comment.

class ArticleComment < Comment
  belongs_to Article
end

# User comment.

class UserComment < Comment
  belongs_to :author, User
end

# Another child class.

class Part
  attr_accessor :name, String
  belongs_to Article
  
  def initialize(name = nil)
    @name = name
  end
  
  def to_s
    return @name
  end
end

# Og configuration.

config = {
  :destroy => true, # destroy table created from earlier runs.
  :store => :sqlite,
  :name => 'test',
  :user => "postgres",
  :password => "gmrulez"
}

# Initialize Og

db = Og.setup(config)

# Create some articles

a1 = Article.new('Title1', 'Body1')
a1.save

# shortcut

a2 = Article.create('Title2', 'Body2')

puts "\n\n"
puts "* Get and print all articles:"
articles = Article.all
articles.each { |a| puts a }

# Create some comments

c1 = ArticleComment.new('Comment 1')
c1.article = a1
c1.save

c2 = ArticleComment.new('Comment 2')
# alternative way to set the parent.
c2.article_oid = a1.oid
# an alternative way to save 
db.store << c2

# an alternative (easier and cooler) way to add children in a 
# has_many relation:
c3 = ArticleComment.new('Comment 3')
# add_comment is automatically added by Og.
a1.comments << c3

puts "\n\n"
puts "* Print all all comments for article 1:"
a1.comments.each { |c| puts c }

# Most Og commands allow you to fine-tune the low level
# SQL code by passing extra_sql parameters, here is an
# example
puts "\n\n"
puts "* comments with sql finetunings:"
# use a standard SQL limit clause
a1.comments(:limit => 2).each { |c| puts c }


# Change a managed object
a1.title = 'Changed Title'
# Og knows that this is a managed object and executes
# an SQL UPDATE instead of an SQL INSERT
a1.save!

puts "\n\n"
Article.all.each { |a| puts a }

# The previous command updates the whole object. It is used
# when there are many updates or you dont care about speed. 
# You can also update specific fields
a2.title = 'A specific title'
a2.update(:properties => [:title])

puts "\n\n"
Article.all.each { |a| puts a }

# delete an object
puts '-----------------1'
ArticleComment.delete(c3)
puts '-----------------2'

puts "\n\n"
ArticleComment.all.each { |a| puts a }


# Serialize a hash
a1.options = { :k1 => 'val1', :k2 => 'val2' }
a1.save!

# lookup an object
article = Article[a1.oid]

puts "\n\n"
puts article.options.inspect

u = User.new('gmosx')
u.save!

article = Article[1]
# you can also lookup by the name property.
article.author = User.find_by_name('gmosx')  
article.save!

part = Part.new('admin')
part.article = article
part.save!

article.parts.each { |pa| puts pa }

puts "\n\n"
puts '---'

c1 = Category.create('Category1')
c2 = Category.create('Category2')

article.categories << c1
article.categories << c2

puts '---'

article.categories.each { |c| puts c.title }

puts '---'

c2.articles.each { |a| puts a.title }

article.categories.delete(c1)

puts '---'

article.categories.each { |c| puts c.title }

# create and save the article in one step.
article = Article.create('title', 'body')

puts '--', article.oid
