BlockFrame = FrameClass.new do
  attr_reader :kwoptarg_ids, :parent_frame

  attr_accessor :block

  def initialize(parent_frame:, block_args:)
    self._self = parent_frame._self
    self.nesting = parent_frame.nesting
    self.locals = Locals.new

    @parent_frame = parent_frame

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
