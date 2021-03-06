require_relative './executor'
require_relative './vm/frames'
require_relative './vm/iseq'
require_relative './vm/errors'

class VM
  attr_reader :frame_stack
  attr_accessor :debug
  attr_accessor :debug_focus_on
  attr_accessor :debug_print_stack

  def initialize
    @frame_stack = FrameStack.new
    @executor = Executor.new

    @jump = nil
    @previous_frame = nil
  end

  def self.instance
    @_instance ||= new
  end

  def execute(iseq, **payload)
    iseq = ISeq.new(iseq)

    begin
      push_frame(iseq, **payload)
    rescue Exception => e
      puts e
      raise InternalError, "Errors inside push_frame are not allowed"
    end

    pushed_frame = current_frame

    if (before_eval = payload[:before_eval]); before_eval.call; end

    __log { "\n\n--------- BEGIN #{current_frame.header} ---------" }

    begin
      current_frame.prepare
      evaluate_last_frame
    rescue LongJumpError => e
      assert_frame(pushed_frame)
      e.do_jump!
    rescue Exception => e
      assert_frame(pushed_frame)
      pop_frame(reason: "propagating #{e}")
      raise
    end

    __log { "\n\n--------- END   #{current_frame.header} ---------" }

    assert_frame(pushed_frame)
    pop_frame(reason: "fully evaluated, returning")
  end

  def assert_frame(expected_frame)
    if !expected_frame.equal?(current_frame)
      raise InternalError, <<-HERE
        must pop what was pushed
        Expected: #{expected_frame.header}
        Got: #{current_frame.header}
      HERE
    end
  end

  def push_frame(iseq, **payload)
    case iseq.kind
    when :top
      @frame_stack.push_top(
        iseq: iseq
      )
    when :eval
      @frame_stack.push_eval(
        iseq: iseq,
        parent_frame: current_frame,
        _self: payload[:_self]
      )
    when :class
      case
      when iseq.name.start_with?('<module')
        @frame_stack.push_module(
          iseq: iseq,
          parent_frame: current_frame,
          name: payload[:name],
          scope: payload[:scope]
        )
      when iseq.name.start_with?('<class')
        @frame_stack.push_class(
          iseq: iseq,
          parent_frame: current_frame,
          name: payload[:name],
          superclass: payload[:superclass],
          scope: payload[:scope]
        )
      when iseq.name == 'singleton class'
        @frame_stack.push_sclass(
          iseq: iseq,
          parent_frame: current_frame,
          of: payload[:of]
        )
      else
        raise NotImplementedError, "Unknown iseq name #{iseq.name}"
      end

    when :method
      @frame_stack.push_method(
        iseq: iseq,
        parent_nesting: payload[:parent_nesting],
        _self: payload[:_self],
        arg_values: payload[:method_args],
        block: payload[:block]
      )
    when :block
      @frame_stack.push_block(
        iseq: iseq,
        parent_frame: payload[:parent_frame],
        arg_values: payload[:block_args],
        block: payload[:block]
      )
    when :rescue
      @frame_stack.push_rescue(
        iseq: iseq,
        parent_frame: current_frame,
        caught: payload[:caught],
        exit_to: payload[:exit_to]
      )
    when :ensure
      @frame_stack.push_ensure(
        iseq: iseq,
        parent_frame: current_frame
      )
    else
      raise NotImplementedError, "Unknown iseq kind #{iseq.kind}"
    end
    __log { "Pushing frame #{current_frame.header}" }
  end

  def pop_frame(reason: 'unknown')
    if @frame_stack.size == 0
      raise InternalError, 'no frame to pop'
    end

    frame = @frame_stack.pop
    __log { "Destroying frame #{frame.header} [#{reason}]" }
    if frame.is_a?(RescueFrame)
      __log { "Jumping into post-rescue" }
      jump(frame.exit_to)
    end
    frame.returning
  end

  def evaluate_last_frame
    initial_frame_stack_size = frame_stack.size

    loop do
      raise InternalError, 'malformed frame stack' if frame_stack.size < initial_frame_stack_size

      if current_insns.empty?
        if frame_stack.size == initial_frame_stack_size
          # done with the root iseq
          break
        else
          # done with intermediate iseq
          raise InternalError, "unexpected"
          pop_frame(reason: 'dead')
          next
        end
      end

      unless @previous_frame.equal?(current_frame)
        __log { "  ====== switching to #{current_frame.pretty_name}  =========" }
      end
      @previous_frame = current_frame

      current_insn = current_iseq.shift_insn

      execute_insn(current_insn)
    end
  end

  def focused?
    current_frame.pretty_name.include?(debug_focus_on)
  end

  def __log(&blk)
    return unless debug
    return if debug_focus_on && !focused?

    if debug_print_stack && current_frame
      $debug.puts "Stack: #{current_frame.stack.inspect}"
    end

    $debug.print "-->" * @frame_stack.size
    $debug.print " "
    $debug.puts blk.call
  end

  def pretty_insn(insn)
    return insn unless insn.is_a?(Array)

    name, *payload = insn
    case name
    when :defineclass
      [name, payload[0], '...class body omitted']
    when :putiseq
      [name, payload[0][5], '...method body omitted']
    when :send
      [name, *payload[0..-2], '...block omitted']
    else
      insn
    end
  end

  def clear_current_iseq
    current_iseq.insns.each { |insn| skip_insn(insn) }
    current_iseq.insns.clear
  end

  def execute_insn(insn)
    case insn
    when Integer
      __log { insn }
      @last_numeric_insn = insn
    when :RUBY_EVENT_LINE
      __log { insn }
      current_frame.line = @last_numeric_insn
      @last_numeric_insn = nil
    when [:leave]
      if current_stack.empty?
        __log { "#{insn.inspect}" }
        raise InternalError, <<~MSG
          Stack is empty, cannot to [:leave].
          current_frame is #{current_frame.header}
          current_frame.returning is #{current_frame.returning}
        MSG
      end
      current_frame.returning = returning = current_stack.pop
      __log { "#{insn.inspect} (returning #{returning.inspect})" }
      clear_current_iseq
    when Array
      execute_array_insn(insn)
    when :RUBY_EVENT_END, :RUBY_EVENT_CLASS, :RUBY_EVENT_RETURN, :RUBY_EVENT_B_CALL, :RUBY_EVENT_B_RETURN, :RUBY_EVENT_CALL
      __log { insn }
      # ignore
    when /label_\d+/
      __log { insn }
      on_label(insn)
      # ignore
    else
      raise NotImplementedError, "Unknown insn kind #{insn.inspect}"
    end
  end

  def execute_array_insn(insn)
    name, *payload = insn

    __log { pretty_insn(insn).inspect }

    with_error_handling do
      @executor.send(:"execute_#{name}", payload)
    end
  end

  def with_error_handling
    yield
  rescue InternalError => e
    raise
  rescue Exception => e
    handle_error(e)
  end

  def handle_error(error)
    if current_frame.enabled_ensure_handlers.length > 1
      raise InternalError, "current_frame.enabled_ensure_handlers > 1"
    end

    if (rescue_handler = current_frame.enabled_rescue_handlers[0])
      result = execute(rescue_handler.iseq, caught: error, exit_to: rescue_handler.exit_label)
      current_stack.push(result)
    else
      raise
    end
  end

  def skip_insn(insn)
    __log { "... #{pretty_insn(insn).inspect}" }
    if insn.is_a?(Symbol) && insn =~ /label_\d+/
      on_label(insn)
    end
  end

  def current_frame; frame_stack.top; end
  def current_self;  current_frame._self; end
  def current_iseq; current_frame.iseq; end
  def current_insns; current_iseq.insns; end
  def current_stack; current_frame.stack; end
  def current_nesting; current_frame.nesting; end
  def backtrace; @frame_stack.to_backtrace; end

  def _raise(klass, msg)
    e = klass.new(msg)
    e.set_backtrace(backtrace)
    raise e
  end

  def jump(label)
    insns = current_iseq.insns

    loop do
      if insns.empty?
        # it can be a jump back via `while` loop
        if current_iseq.initially_had_insn?(label)
          current_iseq.reset!
          current_iseq.insns.drop_while { |insn| insn != label }
          insns = current_iseq.insns
        else
          raise InternalError, 'empty insns list, cannot jump'
        end
      end

      break if insns[0] == label
      skip_insn(insns.shift)
    end

    skip_insn(insns.shift) # shift the label itself
  end

  def on_label(label)
    {
      current_iseq.rescue_handlers => current_frame.enabled_rescue_handlers,
      current_iseq.ensure_handlers => current_frame.enabled_ensure_handlers,
    }.each do |all_handlers, enabled_handlers|
      all_handlers
        .select { |handler| handler.begin_label == label }
        .each { |handler| enabled_handlers << handler }

      all_handlers
        .select { |handler| handler.end_label == label }
        .each { |handler| enabled_handlers.delete(handler) }
    end
  end
end
