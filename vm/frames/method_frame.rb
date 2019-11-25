require_relative "../helpers/method_arguments"

MethodFrame = FrameClass.new do
  attr_reader :arg_values
  attr_reader :kwoptarg_ids

  attr_accessor :block

  def initialize(parent_nesting:, _self:, arg_values:, block:)
    self._self = _self
    self.nesting = parent_nesting
    self.locals = Locals.new

    self.block = block

    @arg_values = arg_values.dup

    MethodArguments.new(
      iseq: _iseq,
      values: arg_values,
      locals: locals
    ).extract

    @kwoptarg_ids = (_iseq.args_info[:keyword] || []).grep(Array).map { |name,| locals.find(name: name).id }
  end

  def pretty_name
    "#{_self.class}##{name}"
  end
end
