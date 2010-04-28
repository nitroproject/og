require "english/inflect"

# The default Tag implementation. A tag attaches semantics to
# a given object.
#--
# FIXME: use index and char() instead of String.
#++

class Tag
  is Anise

  attr_accessor :name, String, :sql=> "VARCHAR(128)", :uniq => true, :key => true
  attr_accessor :count, Fixnum

  # An alias for count.

  alias_method :freq, :count
  alias_method :frequency, :count

  def initialize(name = nil)
    @name = name
    @count = 0
  end

  # Tag an object.

  def tag(obj)
    #--
    # FIXME: this does not work as expected :( it alters
    # the @loaded flag in the obj.tags collection without
    # setting the @members.
    # INVESTIGATE: why this happens!
    #
    # return if obj.tagged_with?(@name)
    # class_name = obj.class.name
    # method_name = class_name.index('::') ? (class_name =~ /.*?\:\:(.*)/; $1) : class_name
    # send(method_name.pluralize.underscore.to_sym) << obj
    #++
    unless obj.tagged_with?(name)
      obj.tags << self
      @count += 1
      update_attribute(:count)
    end
  end
  alias_method :link, :tag

  # Untags an object. If no object is passed, it just decrements
  # the (reference) count. If the count reaches 0 the tag is
  # deleted (garbage collection).

  def untag(obj = nil)
    if obj
      # TODO: implement me.
    end

    @count -= 1

    if @count > 0
      update_attribute(:count)
    else
      self.delete()
    end
  end
  alias_method :unlink, :untag

  # Return all tagged objects from all categories.

  def tagged
    t = []
    self.class.relations.each do |rel|
      t += rel[:target_class].find_with_any_tag(name)
    end
    return t
  end

  def to_s
    @name
  end

  #--
  # gmosx: Extra check, useful for utf-8 names on urls.
  #++

  def to_s_safe
    if /^(\w|\s)+$/ =~ @name
      @name #.gsub(/\s/, "-")
    else
      @oid.to_s
    end
  end

  # Used to alphabetically order Tags. (for tag clouds etc).

  def <=>(other)
    if other.name.downcase < self.name.downcase
      -1
    elsif other.name.downcase > self.name.downcase
      1
    else
      0
    end
  end

  class << self

  def total_frequency(tags = Tag.all)
    tags.inject(1) { |total, t| total += t.count }
  end

  def top(limit = 10)
    Tag.find(:order => "count DESC", :limit => limit)
  end
  alias_method :most_popular, :top

  end

end

module Og::Mixin

# Add tagging methods to the target class.
# For more information on the algorithms used surf:
# http://www.pui.ch/phred/archives/2005/04/tags-database-schemas.html
#
# Example:
#
#   class Article
#     is Taggable
#     ..
#   end
#
#   article.tag('great', 'gmosx', 'nitro')
#   article.tags
#   article.tag_names
#   Article.find_with_tags('great', 'gmosx')
#   Article.find_with_any_tag('name', 'gmosx')
#
#   Tag.find_by_name('ruby').articles

module Taggable

  # The tag string separator.

  setting :separator, :default => ",", :doc => "The tag string separator"

  #is Anise

  is Og::Model

  # Add a tag for this object.

  def tag(the_tags, options = {})
    options = {
      :clear => true
    }.merge(options)

    delete_all_tags() if options[:clear]

    for name in Taggable.tags_to_names(the_tags)
      the_tag = Tag.find_or_create_by_name(name)
      the_tag.tag(self)
    end
  end
  alias_method :tag!, :tag

  # Delete a single tag from this taggable object.

  def delete_tag(name)
    if dtag = (tags.delete_if { |t| t.name == name }).first
      dtag.unlink
    end
  end

  # Delete all tags from this taggable object.

  def delete_all_tags
    for tag in tags
      tag.reload
      tag.unlink
    end
    tags.clear
  end
  alias_method :clear_tags, :delete_all_tags

  # Return the names of the tags.

  def tag_names
    tags.collect { |t| t.name }
  end

  # Return the tag string

  def tag_string(separator = "#{Taggable.separator} ")
    tags.collect { |t| t.name }.join(separator)
  end

  # Return the linked tag string.
  # Typically you will override this in your application.

  def tag_string_linked(separator = Taggable.separator, mount = nil)
    mount ||= self.class::Controller.mount_path
    tags.collect { |t| %|<a href="#{mount}/tagged/#{t.to_s_safe}">#{t}</a>| }.join(separator+" ")
  end

  # Checks to see if this object has been tagged
  # with +tag_name+.

  def tagged_with?(tag_name)
    tag_names.include?(tag_name)
  end
  alias_method :tagged_by?, :tagged_with?

  # Taggable class-level extensions.

  module Self
    # Find objects with all of the provided tags.
    # INTERSECTION (AND)

    def find_with_tags(*names)
      ogmanager.with_store do |store|
        relation = relations.reject{|r| r.name != :tags}.first
        info = store.join_table_info(relation)
        count = names.size
        names = names.map { |n| store.quote(n) }.join(',')
      end
      sql = %{
        SELECT *
        FROM #{info[:owner_table]} AS o
        WHERE o.oid IN (
          SELECT j.#{info[:owner_key]}
          FROM #{info[:target_table]} AS t
          JOIN #{info[:table]} AS j
          ON t.oid = j.#{info[:target_key]}
          WHERE (t.name IN (#{names}))
          GROUP BY j.#{info[:owner_key]}
          HAVING COUNT(j.#{info[:owner_key]}) = #{count}
        )
      }
      return self.select(sql)
    end
    alias_method :find_with_tag, :find_with_tags

    # Find objects with any of the provided tags.
    # UNION (OR)

    def find_with_any_tag(*names)
      ogmanager.with_store do |store|
        relation = relations.reject{|r| r.name != :tags}.first
        info = store.join_table_info(relation)
        count = names.size
        names = names.map { |n| store.quote(n) }.join(',')
      end
      sql = %{
        SELECT *
        FROM #{info[:owner_table]} AS o
        WHERE o.oid IN (
          SELECT j.#{info[:owner_key]}
          FROM #{info[:target_table]} AS t
          JOIN #{info[:table]} AS j
          ON t.oid = j.#{info[:target_key]}
          WHERE (t.name IN (#{names}))
          GROUP BY j.#{info[:owner_key]}
          )
      }
      return self.select(sql)
    end
  end

  #

  def self.included(base)
    Tag.many_to_many base
    #base.extend ClassMethods # Taken care of by Self.
    base.many_to_many Tag
    #--
    # FIXME: Og should handle this automatically.
    #++
    base.before :on_delete do
      tags.clear
    end
  end

  # Converts a tag string to an array of names. Also cleans up
  # the names by removing leading/trailing whitespace.

  def self.tags_to_names(the_tags, separator = Taggable.separator)
    if the_tags.is_a? Array
      names = the_tags
    elsif the_tags.is_a? String
      names = the_tags.gsub(/(,|\s)$/, "").split(separator)
    end

    names = names.flatten.uniq.compact

    # Cleanup excessive whitespace.
    names.collect! { |n| n.gsub(/^\s*|\s*$/, "").gsub(/\s{2,100}/, " ") }

    return names
  end
end

end
