require_relative './executor'
require_relative './vm/frames'
require_relative './vm/iseq'

class VM
  attr_reader :frame_stack
  attr_accessor :debug_focus_on
  attr_accessor :debug_show_stack
  attr_accessor :debug_print_rest_on_error

  class LocalJumpError < ::LocalJumpError
    def initialize(value)
      @value = value
    end
    attr_reader :value
  end

  class InternalError < ::RuntimeError; end

  def initialize
    @frame_stack = FrameStack.new
    # @frame_stack.singleton_class.prepend(Module.new {
    #   def push(v)
    #     super(v)
    #     puts "frame.push [#{size}] #{stack.last(3).map(&:pretty_name).join(' -> ')}"
    #   end
    #   def pop
    #     super()
    #     puts "frame.pop  [#{size}] #{stack.last(3).map(&:pretty_name).join(' -> ')}"
    #   end
    # })
    @executor = Executor.new

    @jump = nil
  end

  def self.instance
    @_instance ||= new
  end

  def execute(iseq, **payload)
    iseq = ISeq.new(iseq)

    depth_before = frame_stack.size

    push_frame(iseq, **payload)

    if (before_eval = payload[:before_eval]); before_eval.call; end

    __log "\n\n--------- BEGIN #{current_frame.header} ---------"
    evaluate_last_frame
    __log "\n\n--------- END   #{current_frame.header} ---------"
  ensure
    result = pop_frame

    if $! && !$!.is_a?(InternalError)
      raise
    end

    if @frame_stack.size != depth_before
      raise InternalError, 'frame stack is inconsistent'
    end

    return result
  end

  def push_frame(iseq, **payload)
    case iseq.kind
    when :top
      @frame_stack.push_top(
        iseq: iseq
      )
    when :class
      case
      when iseq.name.start_with?('<module')
        @frame_stack.push_module(
          iseq: iseq,
          parent_frame: current_frame,
          name: payload[:name]
        )
      when iseq.name.start_with?('<class')
        @frame_stack.push_class(
          iseq: iseq,
          parent_frame: current_frame,
          name: payload[:name],
          superclass: payload[:superclass]
        )
      when iseq.name == 'singleton class'
        @frame_stack.push_sclass(
          iseq: iseq,
          parent_frame: current_frame,
          of: payload[:cbase]
        )
      else
        binding.irb
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
        block_args: payload[:block_args],
      )
    when :rescue
      @frame_stack.push_rescue(
        iseq: iseq,
        parent_frame: current_frame,
        caught: payload[:caught]
      )
    when :ensure
      @frame_stack.push_ensure(
        iseq: iseq,
        parent_frame: current_frame
      )
    else
      binding.irb
    end
  end

  def pop_frame
    expected_size = @frame_stack.size - 1

    error_to_reraise = nil

    if (error = current_frame.current_error)
      if (rescue_iseq = current_frame.iseq.handler(:rescue))
        execute(rescue_iseq, caught: error)
      else
        error_to_reraise = error
      end

      if (ensure_iseq = current_frame.iseq.handler(:ensure))
        execute(ensure_iseq)
      end
    end

    current_frame.returning
  ensure
    @frame_stack.pop while @frame_stack.size > expected_size

    raise error_to_reraise if error_to_reraise
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
          pop_frame
          next
        end
      end

      unless @previous_frame.equal?(current_frame)
        __log "  ====== switching to #{current_frame.pretty_name}  ========="
      end
      @previous_frame = current_frame

      current_insn = current_iseq.shift_insn

      begin
        execute_insn(current_insn)
      rescue
        if debug_print_rest_on_error
          $debug.puts "--------------\nRest (for #{current_frame.pretty_name} in #{current_frame.file}):"
          current_iseq.insns.each { |insn| p insn }
        end
        raise
      end
    end
  end

  def focused?
    current_frame.pretty_name.include?(debug_focus_on)
  end

  def __log(string)
    return if debug_focus_on && !focused?

    if debug_show_stack
      $debug.puts "Stack: #{current_frame.stack.inspect}"
    end

    $debug.print "-->" * @frame_stack.size
    $debug.print " "
    $debug.puts string
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
    current_iseq.insns.each { |insn| report_skipped_insn(insn) }
    current_iseq.insns.clear
  end

  def execute_insn(insn)
    case insn
    when Integer
      @last_numeric_insn = insn
    when :RUBY_EVENT_LINE
      current_frame.line = @last_numeric_insn
      @last_numeric_insn = nil
    when [:leave]
      current_frame.returning = returning = current_stack.pop
      __log "#{insn.inspect} (returning #{returning.inspect})"
      clear_current_iseq
    when Array
      execute_array_insn(insn)
    when :RUBY_EVENT_END, :RUBY_EVENT_CLASS, :RUBY_EVENT_RETURN, :RUBY_EVENT_B_CALL, :RUBY_EVENT_B_RETURN, :RUBY_EVENT_CALL
      # ignore
    when /label_\d+/
      # ignore
    else
      binding.irb
    end
  end

  def execute_array_insn(insn)
    name, *payload = insn

    __log pretty_insn(insn).inspect

    with_error_handling do
      @executor.send(:"execute_#{name}", payload)
    end
  end

  def with_error_handling
    yield
  rescue => e
    if e.is_a?(InternalError)
      # our error, just re-raise ie
      raise
    end

    # error from the inerpreted code
    clear_current_iseq
    current_frame.current_error = e
  end

  def report_skipped_insn(insn)
    __log "... #{pretty_insn(insn).inspect}"
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
      report_skipped_insn(insns.shift)
    end

    report_skipped_insn(insns.shift) # shift the label itself
  end
end
