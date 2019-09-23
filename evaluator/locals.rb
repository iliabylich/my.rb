require 'set'

Local = Struct.new(:name, :id, :value, :initialized, :optarg, keyword_init: true) do
  def get
    value
  end

  def set(value, optarg: nil)
    self.value = value
    self.initialized = true
    self.optarg = true if optarg
    value
  end
end

class Locals
  def initialize
    @set = Set.new
  end

  def declare(name: nil, id: nil)
    @set << Local.new(name: name, id: id, value: nil, initialized: false)
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
      .map { |local| ["#{local.name}(#{local.id})", local.initialized ? local.value : "unitialized"] }
      .to_h
  end
end
