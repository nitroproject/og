require "rubygems"

Gem::Specification.new do |s|
  s.name = "og"
  s.version = "0.50.0"
  s.date = Time.now.to_s
  s.author = "George K. Moschovitis"
  s.summary = "State of the art object-relational mapping system"
  s.description = <<-EOS
  Object Graph (Og) is a state of the art ORM system.
  Og serializes standard Ruby objects to Mysql, Postgres, Sqlite,
  KirbyBase, Filesystem and more.
  EOS
  
  s.homepage = "http://www.nitroproject.org"
  s.files = Dir.glob("{bin,lib,test,doc}/**/*")
  s.files.concat %w{README INSTALL}
  s.require_path = "lib"
  s.has_rdoc = true

  s.add_dependency("facets", ">= 2.2.1")
  s.add_dependency("opod", ">= 0.0.1")
  s.add_dependency("english", ">= 0.1")
end
