class FrameStack
  include Enumerable

  def initialize
    @stack = []
  end

  def each
    return to_enum(__method__) unless block_given?

    @stack.each { |item| yield item }
  end

  def push_top(**args)
    @stack << TopFrame.new(**args)
  end

  def push_class(**args)
    @stack << ClassFrame.new(**args)
  end

  def push_module(**args)
    @stack << ModuleFrame.new(**args)
  end

  def push_sclass(**args)
    @stack << SClassFrame.new(**args)
  end

  def push_method(**args)
    @stack << MethodFrame.new(**args)
  end

  def push_block(**args)
    @stack << BlockFrame.new(**args)
  end

  def push_rescue(**args)
    @stack << RescueFrame.new(**args)
  end

  def push_ensure(**args)
    @stack << EnsureFrame.new(**args)
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
