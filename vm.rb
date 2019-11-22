require_relative './executor'
require_relative './vm/frames'
require_relative './vm/iseq'

class VM
  attr_reader :stack

  def initialize
    @stack = []
    @stack.singleton_class.prepend(Module.new {
      def pop
        if length == 0
          raise 'stack is empty, there is nothing to pop'
        end
        super
      end
    })
    @frame_stack = FrameStack.new
    @iseq_stack = []
    @executor = Executor.new

    @jump = nil
  end

  def self.instance
    @_instance ||= new
  end

  def execute(iseq, **payload)
    iseq = ISeq.new(iseq)

    @iseq_stack.push(iseq)

    push_frame_for_iseq(iseq, **payload)
    __log "\n\n--------- BEGIN #{current_frame.header} ---------"

    result = evaluate_until_stack_size_is(@iseq_stack.size - 1)

    __log "\n\n--------- END   #{current_frame.header} ---------"
    pop_frame

    result
  end

  def push_frame_for_iseq(iseq, **payload)
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
        block_args: payload[:block_args]
      )
    else
      binding.irb
    end
  end

  def pop_frame
    @frame_stack.pop
  end

  def evaluate_until_stack_size_is(size)
    last_value = :UNDEFINED

    loop do
      break if @iseq_stack.size == size

      if current_iseq.insns.empty?
        @iseq_stack.pop
        next
      end

      current_insn = current_iseq.shift_insn

      begin
        last_value = execute_insn(current_insn)
      rescue
        $debug.puts "--------------\nRest (for #{current_frame.pretty_name} in #{current_frame.file}):"
        current_iseq.insns.each { |insn| p insn }
        raise
      end
    end

    last_value
  end

  def __log(string)
    $debug.print "-->" * @frame_stack.size
    $debug.print " "
    $debug.puts string
  end

  def execute_insn(insn)
    case insn
    when Integer
      @last_numeric_insn = insn
    when :RUBY_EVENT_LINE
      current_frame.line = @last_numeric_insn
      @last_numeric_insn = nil
    when [:leave]
      returning = @stack.pop
      __log "#{insn.inspect} (returning #{returning.inspect})"
      current_iseq.insns.each { |insn| report_skipped_insn(insn) }
      current_iseq.insns.clear
      return returning
    when Array
      name, *payload = insn

      case name
      when :defineclass
        __log [name, payload[0], '...omitted'].inspect
      when :putiseq
        __log [name, payload[0][5], '...omitted'].inspect
      else
        __log insn.inspect
      end

      @executor.send(:"execute_#{name}", payload)
    when :RUBY_EVENT_END, :RUBY_EVENT_CLASS, :RUBY_EVENT_RETURN, :RUBY_EVENT_B_CALL, :RUBY_EVENT_B_RETURN, :RUBY_EVENT_CALL
      # ignore
    when /label_\d+/
      # ignore
    else
      binding.irb
    end

    return
  end

  def report_skipped_insn(insn)
    __log "... #{insn.inspect}"
  end

  def current_iseq; @iseq_stack.last; end
  def current_frame; @frame_stack.top; end
  def current_self;  current_frame._self; end
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
      binding.irb if insns.empty?
      break if insns[0] == label
      report_skipped_insn(insns.shift)
    end

    report_skipped_insn(insns.shift) # shift the label itself
  end
end
