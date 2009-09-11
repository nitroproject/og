# = Mysql to PostgreSQL migration example.
#
# A simple example to demonstrate the flexibility of
# Og. Two connections to different databases are 
# created and data is copied from a MySQL database
# to a PostgreSQL database.
#
# Og makes it easier to switch to a REAL database :)

require 'og'

# Configure databases.

psql_config = {
  :destroy => true,
  :name => 'test',
  :store => 'psql',
  :user => 'postgres',
  :password => 'gmrulez'
}

mysql_config = {
  :destroy => true,
  :name => 'test',
  :store => 'mysql',
  :user => 'root',
  :password => 'gmrulez'
}

# Initialize Og.

psql = Og.connect(psql_config)
mysql = Og.connect(mysql_config)

# An example managed object.
# Looks like an ordinary Ruby object.

class Article
  attr_accessor :name, :body, String

  def initialize(name = nil, body = nil)
    @name, @body = name, body
  end
end

# First populate the mysql database.

mysql.manage(Article)

a1 = Article.create('name1', 'body1')
a1 = Article.create('name1', 'body1')
a1 = Article.create('name1', 'body1')

# Read all articles from Mysql.

articles = Article.all

# Switch to PostgreSQL.

psql.manage(Article)

# Store all articles.

for article in articles
  article.insert
end

# Fetch an article from PostgreSQL
# as an example. Lookup by name.

article = Article.find_by_name('name1')
