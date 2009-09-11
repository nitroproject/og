require File.join(File.dirname(__FILE__), 'helper.rb')

require 'og/model/cacheable'
require 'glue/cache/memory'
require 'glue/cache/file'
require 'glue/cache/memcached'
require 'glue/cache/drb'


[Glue::MemoryCache, Glue::FileCache, Glue::MemCached, Glue::DrbCache].each do |cache_class|
  
  describe "Og Cache: #{cache_class}" do
    
    setup do
      class User
        is Og::Mixin::Cacheable

        attr_accessor :name, String
        attr_accessor :age, Fixnum
        attr_accessor :permissions, Array
      end
      
      @store = quick_setup(User)
      
      begin
        User.ogmanager.cache = cache_class.new
      rescue Exception => e
        User.ogmanager.cache = nil
      end
      
    end
    
    it "should cache Og models" do
      unless User.ogmanager.cache
        msg = "Failed for cache type: #{cache_class}"
        return
      end

      User.create_with :name => 'George'
      User.create_with :name => 'Stella'
     
      u = User[1]
      u.permissions = %w[1 2 3]
      u.save

      u.name.should == 'George'

      # Comes from the cache.
      
      u = User[1]
      u = User[1]
      u = User[1]

      User.ogmanager.cache.get(u.og_cache_key).should == u
    
      u.name = 'Hello'
      u.save
      
      u = User[1]
      u = User[1]
      
      User.ogmanager.cache.get(u.og_cache_key).name.should == u.name
      User.ogmanager.cache.get(u.og_cache_key).permissions.should == %w[1 2 3]
      
      u.delete
      User.delete(2)
    end
    
  end
  
end


__END__

class TC_MemoryCacheable < Test::Unit::TestCase # :nodoc: all
  class User
    is Glue::Cacheable
    
    attr_accessor :name, String
    attr_accessor :age, Fixnum
  end

  $og1.manage_classes(User)

  Caches = [Glue::MemoryCache]

  def setup
    @og = User.ogmanager
#   @og.cache = Glue::DrbCache.new(:address => Og.cache_address, :port => Og.cache_port)
  end

  def teardown
    @og.cache = nil
  end

  def test_all
    Caches.each do |cache_class|
  #   @og.cache = DrbCache.new(:address => Og.cache_address, :port => Og.cache_port)
      @og.cache = cache_class.new
      
      msg = "Failed for cache type: #{cache_class}"

      User.create_with :name => 'George'
      User.create_with :name => 'Stella'
     
      u = User[1]
      
      assert_equal 'George', u.name, msg

      # Comes from the cache.
      
      u = User[1]
      u = User[1]
      u = User[1]

      assert_equal u, @og.cache.get(u.og_cache_key), msg
    
      u.name = 'Hello'
      u.save
      
      u = User[1]
      u = User[1]
      
      assert_equal u.name, @og.cache.get(u.og_cache_key).name, msg
      
      u.delete
      User.delete(2)
    end
  end
end

class TC_FileCacheable < Test::Unit::TestCase # :nodoc: all
  class User
    is Glue::Cacheable
    
    attr_accessor :name, String
    attr_accessor :age, Fixnum
    attr_accessor :permissions, Array
  end

  $og1.manage_classes(User)

  Caches = [Glue::FileCache]

  def setup
    Glue::FileCache.basedir = File.join(File.dirname(__FILE__), '..', 'cache')
    FileUtils.rm_r Glue::FileCache.basedir if File.exists? Glue::FileCache.basedir

    @og = User.ogmanager
#   @og.cache = Glue::DrbCache.new(:address => Og.cache_address, :port => Og.cache_port)
  end

  def teardown
    @og.cache = nil
  end

  def test_all
    Caches.each do |cache_class|
  #   @og.cache = DrbCache.new(:address => Og.cache_address, :port => Og.cache_port)
      @og.cache = cache_class.new
      
      msg = "Failed for cache type: #{cache_class}"

      User.create_with :name => 'George'
      User.create_with :name => 'Stella'
     
      u = User[1]
      u.permissions = %w[1 2 3]
      u.save

      assert_equal 'George', u.name, msg

      # Comes from the cache.
      
      u = User[1]
      u = User[1]
      u = User[1]

      assert_equal u, @og.cache.get(u.og_cache_key), msg
    
      u.name = 'Hello'
      u.save
      
      u = User[1]
      u = User[1]
      
      assert_equal u.name, @og.cache.get(u.og_cache_key).name, msg
      assert_equal %w[1 2 3], @og.cache.get(u.og_cache_key).permissions, msg
      
      u.delete
      User.delete(2)
    end
  end
end

begin
  Glue::MemCached.new
  class TC_MemCachedCacheable < Test::Unit::TestCase # :nodoc: all
    class User
      is Glue::Cacheable
      
      attr_accessor :name, String
      attr_accessor :age, Fixnum
    end

    $og1.manage_classes(User)

    Caches = [Glue::MemCached]

    def setup
      @og = User.ogmanager
      #   @og.cache = Glue::DrbCache.new(:address => Og.cache_address, :port => Og.cache_port)
    end

    def teardown
      @og.cache = nil
    end

    def test_all
      Caches.each do |cache_class|
        #   @og.cache = DrbCache.new(:address => Og.cache_address, :port => Og.cache_port)
        @og.cache = cache_class.new(self.class, 60)
        
        msg = "Failed for cache type: #{cache_class}"

        User.create_with :name => 'George'
        User.create_with :name => 'Stella'
        
        u = User[1]
        
        assert_equal 'George', u.name, msg

        # Comes from the cache.
        
        u = User[1]
        u = User[1]
        u = User[1]

        assert_equal u, @og.cache.get(u.og_cache_key), msg
        
        u.name = 'Hello'
        u.save
        
        u = User[1]
        u = User[1]
        
        assert_equal u.name, @og.cache.get(u.og_cache_key).name, msg
        
        u.delete
        User.delete(2)
      end
    end
  end
rescue Errno::ECONNREFUSED => ex # FIXME: Lookup Win32/Linux/BSD error
  Logger.warn "skipping memcached test: server not running"
  #Logger.warn ex.class # FIXME: remove when all error types listed above
end

