require File.join(File.dirname(__FILE__), 'helper.rb')

class Book
  attr_accessor :title, String
  belongs_to :owner, Person
end

class Person
  attr_accessor :name, Og::VarChar(128)
  has_many :books, Book, :foreign_name => :owner
end

describe "Override Og Standard Behaviour" do
  
  before(:each) do
    @old_prefix = Og.table_prefix
    Og.table_prefix = nil
    @store = quick_setup(Book, Person)
  end
  
  after(:each) do
    Og.table_prefix = @old_prefix
    @old_prefix = nil
    og_teardown(@store)
  end

  it "should test_basic" do
    book = Book.create
    person = Person.create
    person.books << book
    
    person.books.size.should == 1
  end
  
  # This tests, if the tables are without prefix, note that changing the
  # Class of the testcase will change the table name.
  
  it "should test_og_prefix" do
    Book.table.should == 'book'
    Person.table.should == 'person'
  end

end

# * Kristof Jozsa <dyn@ond.vein.hu>
