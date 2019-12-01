BlockFrame = FrameClass.new do
  attr_reader :kwoptarg_ids, :parent_frame

  attr_accessor :block

  attr_reader :block_args

  def initialize(parent_frame:, block_args:)
    self._self = parent_frame._self
    self.nesting = parent_frame.nesting
    self.locals = Locals.new

    @parent_frame = parent_frame

    if block_args.is_a?(Array) && block_args.length == 1 && block_args[0].is_a?(Array) && !iseq.args_info[:ambiguous_param0]
      block_args = block_args[0]
    end

    @block_args = block_args
  end

  def prepare
    MethodArguments.new(
      iseq: iseq,
      values: block_args,
      locals: locals
    ).extract

    @kwoptarg_ids = (iseq.args_info[:keyword] || []).grep(Array).map { |name,| locals.find(name: name).id }
  end

  def pretty_name
    name
  end

  def can_do_next?
    true
  end
end
