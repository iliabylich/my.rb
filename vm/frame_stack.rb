class FrameStack
  attr_reader :stack

  include Enumerable

  def initialize
    @stack = []
  end

  def each
    return to_enum(__method__) unless block_given?

    @stack.each { |item| yield item }
  end

  def push(frame)
    @stack << frame
    frame.prepare
    if @stack.size > 100
      raise VM::InternalError, 'stack overflow'
    end
  end

  def push_top(**args)
    push TopFrame.new(**args)
  end

  def push_class(**args)
    push ClassFrame.new(**args)
  end

  def push_module(**args)
    push ModuleFrame.new(**args)
  end

  def push_sclass(**args)
    push SClassFrame.new(**args)
  end

  def push_method(**args)
    push MethodFrame.new(**args)
  end

  def push_block(**args)
    push BlockFrame.new(**args)
  end

  def push_rescue(**args)
    push RescueFrame.new(**args)
  end

  def push_ensure(**args)
    push EnsureFrame.new(**args)
  end

  def pop
    @stack.pop
  end

  def top
    @stack.last
  end

  def size
    @stack.size
  end

  def to_backtrace
    [
      *@stack.map { |frame| BacktraceEntry.new(frame) },
      "... MRI backtrace...",
      *caller,
      "...Internal backtrace..."
    ]
  end
end
