require 'set'

Local = Struct.new(:name, :id, :value, keyword_init: true) do
  def get
    value
  end

  def set(value)
    self.value = value
    value
  end
end

class Locals
  Set = ::Set

  UNDEFINED = Object.new
  def UNDEFINED.inspect; 'UNDEFINED'; end

  def initialize(initial_names)
    @set = Set.new

    initial_names.reverse_each.with_index(3) do |arg_name, idx|
      # unused args (like virtual attribute that holds mlhs value)
      # have have numeric names
      arg_name += 1 if arg_name.is_a?(Integer)
      declare(name: arg_name, id: idx)
      find(id: idx).set(Locals::UNDEFINED)
    end
  end

  def declared?(name: nil, id: nil)
    @set.any? { |local| (!name.nil? && local.name == name) || (!id.nil? && local.id == id) }
  end

  def declare(name: nil, id: nil)
    @set << Local.new(name: name, id: id, value: nil)
  end

  def find(name: nil, id: nil)
    result =
      if name
        @set.detect { |var| var.name == name }
      elsif id
        @set.detect { |var| var.id == id }
      else
        raise NotImplementedError, "At least one of name:/id: is required"
      end

    if result.nil?
      raise VM::InternalError, "No local name=#{name.inspect}/id=#{id.inspect}"
    end

    result
  end

  def pretty
    @set
      .map { |local| ["#{local.name}(#{local.id})", local.value] }
      .sort_by { |(name, value)| name }
      .to_h
  end
end
