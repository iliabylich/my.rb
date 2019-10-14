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

  def initialize
    @set = Set.new
  end

  def declared?(name: nil, id: nil)
    @set.any? { |local| (!name.nil? && local.name == name) || (!id.nil? && local.id == id) }
  end

  def declare(name: nil, id: nil)
    @set << Local.new(name: name, id: id, value: UNDEFINED)
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

    raise "No local name=#{name.inspect}/id=#{id.inspect}" if result.nil?

    result
  end

  def pretty
    @set
      .map { |local| ["#{local.name}(#{local.id})", local.value] }
      .to_h
  end
end
