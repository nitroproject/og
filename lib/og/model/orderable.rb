require "paramix"

module Og::Mixin

# Attach list/ordering methods to the enchanted class.
#
# === Comments
#
# If you use the scope option, you have to set he parent (scope)
# of the object before inserting to have correct ordering.

module Orderable
  is Og::Model #is Anise
  is Paramix::Parametric

  parameterized do |opt|

    # The attribute to use to keep the position.
    
    opt_position = opt.fetch(:position, :position)

    # The type of the position attribute.
    
    opt_type = opt.fetch(:type, Fixnum)

    # A user defined condition.
    
    opt_condition = opt[:condition]

    # A condition based on a key field (?)
    
    opt_scope = opt[:scope]

    # clean scope field.
    
    if opt_scope
      if opt_scope.to_s !~ /_oid$/
        opt_scope = "#{opt_scope}_oid".to_sym
      else
        opt_scope = opt_scope.to_sym
      end
    end

    attr_accessor opt_position, opt_type

    define_method :orderable_attribute do
      opt_position
    end

    define_method :orderable_position do
      instance_variable_get("@#{opt_position}")
    end

    define_method :orderable_position= do |pos|
      instance_variable_set("@#{opt_position}", pos)
    end

    define_method :orderable_type do
      opt_type
    end

    define_method :orderable_scope do
      opt_scope
    end

    define_method :orderable_condition do
      scope = orderable_scope
      if scope
        scope_value = send(scope)
        scope = scope_value ? "#{scope} = #{scope_value}" : "#{scope} IS NULL"
      end
      return [opt_condition, scope].compact
    end

=begin
    #base.module_eval %{
    module_eval %{

      #attr_accessor :#{opt_position}, #{opt_type}

      #def orderable_attribute
      #  #{opt_position.inspect}
      #end
          
      #def orderable_position
      #  @#{opt_position}
      #end

      #def orderable_position= (pos)
      #  @#{opt_position} = pos
      #end

      #def orderable_type
      #  #{opt_type}
      #end
   
      #def orderable_scope
      #  #{opt_scope.inspect}
      #end

      def orderable_condition
        scope = orderable_scope
        if scope
          scope_value = send(scope)
          scope = scope_value ? "\#{scope} = \#{scope_value}" : "\#{scope} IS NULL"
        end
        return [ #{opt_condition.inspect}, scope ].compact
      end
    }
=end

  end 

  before :insert do
    add_to_bottom()
  end

  before :delete do
    decrement_position_of_lower_items()
  end

  # Move higher.
  
  def move_higher
    if higher = higher_item
      self.class.transaction do
        higher.increment_position
        decrement_position
      end
    end
  end
  
  # Move lower.
  
  def move_lower
    if lower = lower_item
      self.class.transaction do
        lower.decrement_position
        increment_position
      end
    end
  end

  # Move to the top.
  
  def move_to_top
    self.class.transaction do
      increment_position_of_higher_items
      set_top_position
    end
  end

  # Move to the bottom.
  
  def move_to_bottom
    self.class.transaction do
      decrement_position_of_lower_items
      set_bottom_position
    end
  end

  # Move to a specific position.
  
  def move_to(dest_position)
    return if self.orderable_position == dest_position

    pos = orderable_attribute
    con = orderable_condition

    self.class.transaction do
      if orderable_position < dest_position
        adj = "#{pos} = #{pos} - 1"
        con = con + [ "#{pos} > #{orderable_position}", "#{pos} <= #{dest_position}" ]
      else
        adj = "#{pos} = #{pos} + 1"
        con = con + [ "#{pos} < #{orderable_position}", "#{pos} >= #{dest_position}" ]
      end
      self.class.update( adj, :condition => con.join(' AND ') )
      self.orderable_position = dest_position
      update_attribute(orderable_attribute)
    end

    self
  end

  def add_to_top
    increment_position_of_all_items
  end

  def add_to_bottom
    self.orderable_position = bottom_position + 1
  end

  def add_to
    # TODO
  end

  def higher_item
    pos = orderable_attribute
    con = orderable_condition + [ "#{pos} = #{orderable_position - 1}" ]
    self.class.one( :condition => con.join(' AND ') )
  end
  alias_method :previous_item, :higher_item

  def lower_item
    pos = orderable_attribute
    con = orderable_condition + [ "#{pos} = #{orderable_position + 1}" ]
    self.class.one( :condition => con.join(' AND ') )
  end
  alias_method :next_item, :lower_item

  def top_item
    # TODO
  end
  alias_method :first_item, :top_item

  def bottom_item
    pos = orderable_attribute
    con = orderable_condition
    con = con.empty? ? nil : con.join(' AND ')
    self.class.one(:condition => con, :order => "#{pos} DESC", :limit => 1)
  end
  alias_method :last_item, :last_item

  def top?
    self.orderable_position == 1
  end
  alias_method :first?, :top?

  def bottom?
    self.orderable_position == bottom_position
  end
  alias_method :last?, :bottom?

  def increment_position
    self.orderable_position += 1
    update_attribute(self.orderable_attribute)
  end

  def decrement_position
    self.orderable_position -= 1
    update_attribute(self.orderable_attribute)
  end

  def bottom_position
    item = bottom_item
    item ? (item.orderable_position || 0) : 0
  end

  def set_top_position
    self.orderable_position = 1
    update_attribute(orderable_attribute)
  end

  def set_bottom_position
    self.orderable_position = bottom_position + 1
    update_attribute(orderable_attribute)
  end

  def increment_position_of_higher_items
    pos = orderable_attribute
    con = orderable_condition + [ "#{pos} < #{orderable_position}" ]
    self.class.update "#{pos}=(#{pos} + 1)",  :condition => con.join(' AND ')
  end

  def increment_position_of_all_items
    pos = orderable_attribute
    con = orderable_condition
    con = con.empty? ? nil : con.join(' AND ')
    self.class.update "#{pos}=(#{pos} + 1)", :condition => con 
  end

  def decrement_position_of_lower_items
    pos = orderable_attribute
    con = orderable_condition + [ "#{pos} > #{orderable_position}" ]
    self.class.update "#{pos}=(#{pos} - 1)",  :condition => con.join(' AND ')
  end

end

end
