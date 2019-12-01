class Stack
  def initialize
    @stack = []
    @push_disabled = false
  end

  def size
    @stack.size
  end

  def [](idx)
    @stack[idx]
  end

  def []=(idx, value)
    @stack[idx] = value
  end

  def push(value)
    return if @push_disabled
    @stack.push(value)
  end

  def pop
    if @stack.empty?
      raise 'stack is empty, cannot do pop'
    end

    @stack.pop
  end

  def top
    @stack.last
  end

  def clear
    @stack.clear
  end

  def disable_push!
    @push_disabled = true
  end
end
