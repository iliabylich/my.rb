require_relative "../helpers/method_arguments"

MethodFrame = FrameClass.new do
  attr_reader :arg_values
  attr_reader :kwoptarg_ids

  attr_reader :block

  def initialize(parent_nesting:, _self:, arg_values:, block:)
    self._self = _self
    self.nesting = parent_nesting

    @block = block
    @arg_values = arg_values.dup
  end

  def prepare
    values = arg_values

    if iseq.args_info[:block_start]
      values << block
    end

    MethodArguments.new(
      iseq: iseq,
      values: values,
      locals: locals
    ).extract

    @kwoptarg_ids = (iseq.args_info[:keyword] || []).grep(Array).map { |name,| locals.find(name: name).id }
  end

  RESPOND_TO = Kernel.instance_method(:respond_to?)

  def pretty_name
    klass = RESPOND_TO.bind(_self).call(:class) ? _self.class : '(some BasicObject)'
    "#{klass}##{name}"
  end

  def can_return?
    true
  end

  def can_yield?
    true
  end
end
