module Og::Mixin

# Search support for Og managed classes.

module Searchable

  # Searchable class-level methods.

  module Self

    # Override this method in your class to customize the
    # search. This is a nice default method.

    def search(query)
      search_props = properties.values.select { |p| p.searchable }
      condition = search_props.collect { |p| "#{p} LIKE '%#{query}%'" }.join(' OR ')
      all(:condition => condition)
    end

  end

end

end
