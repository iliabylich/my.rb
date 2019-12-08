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
      declare(name: arg_name, id: idx).set(Locals::UNDEFINED)
    end
  end

  def declared?(name: nil, id: nil)
    !find_if_declared(name: name, id: id).nil?
  end

  def declare(name: nil, id: nil)
    local = Local.new(name: name, id: id, value: nil)
    @set << local
    local
  end

  def find_if_declared(name: nil, id: nil)
    if name
      @set.detect { |var| var.name == name }
    elsif id
      @set.detect { |var| var.id == id }
    else
      raise NotImplementedError, "At least one of name:/id: is required"
    end
  end

  def find(name: nil, id: nil)
    result = find_if_declared(name: name, id: id)

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
