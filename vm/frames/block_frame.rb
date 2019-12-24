BlockFrame = FrameClass.new do
  attr_accessor :is_lambda
  attr_reader :kwoptarg_ids, :parent_frame

  attr_reader :block

  attr_reader :arg_values

  def initialize(parent_frame:, arg_values:, block:)
    self._self = parent_frame._self
    self.nesting = parent_frame.nesting

    @block = block
    @parent_frame = parent_frame

    if arg_values.is_a?(Array) && arg_values.length == 1 && arg_values[0].is_a?(Array) && !iseq.args_info[:ambiguous_param0]
      arg_values = arg_values[0]
    end

    @arg_values = arg_values
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
    ).extract(arity_check: is_lambda)

    @kwoptarg_ids = (iseq.args_info[:keyword] || []).grep(Array).map { |name,| locals.find(name: name).id }
  end

  def pretty_name
    name
  end

  def can_do_next?
    true
  end

  def can_do_break?
    true
  end
end
