BlockFrame = FrameClass.new do
  attr_reader :kwoptarg_ids, :parent_frame

  attr_accessor :block

  def initialize(parent_frame:, block_args:)
    self._self = parent_frame._self
    self.nesting = parent_frame.nesting
    self.locals = Locals.new

    @parent_frame = parent_frame

    if block_args.is_a?(Array) && block_args.length == 1 && block_args[0].is_a?(Array) && !_iseq[11][:ambiguous_param0]
      block_args = block_args[0]
    end

    @kwoptarg_ids, @labels_to_skip, @block = MethodArguments.new(
      iseq: _iseq,
      values: block_args,
      locals: locals
    ).extract
  end

  def pretty_name
    name
  end
end
