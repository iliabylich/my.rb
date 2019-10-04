class FrameStack
  include Enumerable

  def initialize
    @stack = []
  end

  def each
    return to_enum(__method__) unless block_given?

    @stack.each { |item| yield item }
  end

  def enter_top(**args)
    @stack << TopFrame.new(**args)
    yield
  ensure
    @stack.pop
  end

  def enter_class(**args)
    @stack << ClassFrame.new(**args)
    yield
  ensure
    @stack.pop
  end

  def enter_module(**args)
    @stack << ModuleFrame.new(**args)
    yield
  ensure
    @stack.pop
  end

  def enter_sclass(**args)
    @stack << SClassFrame.new(**args)
    yield
  ensure
    @stack.pop
  end

  def enter_method(**args)
    @stack << MethodFrame.new(**args)
    yield
  ensure
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
