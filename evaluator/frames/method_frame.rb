require_relative "../helpers/method_arguments"

MethodFrame = FrameClass.new do
  attr_reader :kwoptarg_ids

  attr_accessor :block

  def initialize(parent_frame:, _self:, arg_values:, block:)
    self._self = _self
    self.nesting = parent_frame.nesting
    self.locals = Locals.new

    self.block = block

    arg_names = _iseq[10].dup
    args_info = _iseq[11]

    @kwoptarg_ids, @labels_to_skip = MethodArguments.new(
      iseq: _iseq,
      values: arg_values,
      locals: locals
    ).extract
  end

  def pretty_name
    "#{_self.class}##{name}"
  end
end
