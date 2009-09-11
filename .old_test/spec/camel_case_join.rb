require File.join(File.dirname(__FILE__), 'helper.rb')


module OgCamelCase
  
describe "Og CamelCase Joins" do
  
  setup do
    class CategoryCamelCase
      attr_accessor :title, String
      def initialize(title)
        @title = title
      end
    end

    class ArticleCamelCase
      attr_accessor :title, String
      joins_many CategoryCamelCase, :through => ArticleToCategory

      def initialize(title)
        @title = title
      end
    end

    class ArticleToCategory
      attr_accessor :rate, Float
      attr_accessor :hits, Fixnum
      has_one ArticleCamelCase
      has_one CategoryCamelCase
    end
    
    @store = quick_setup(CategoryCamelCase, ArticleCamelCase, ArticleToCategory)
  end
  
  it "should be able to create camel case joins correctly" do
    c1 = CategoryCamelCase.create('tech')
    c2 = CategoryCamelCase.create('funny')
    a = ArticleCamelCase.create('a1')
    a.category_camel_cases.push(c1, :hits =>3, :rate => 2.3)
    a.category_camel_cases.push(c2, :rate => 1.2)
    
    join = a.category_camel_case_join_data(c1)
    join.rate.should == 2.3
    join.hits.should == 3
    
    join = a.category_camel_case_join_data(c2)
    join.rate.should == 1.2
    join.hits.should == nil
  end
end

end
