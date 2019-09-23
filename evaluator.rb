require_relative './evaluator/frames'

class Evaluator
  def initialize
    @stack = []
    @frame_stack = FrameStack.new

    @jump = nil
  end

  def execute(iseq)
    execute_iseq(iseq)
  end

  def execute_iseq(iseq, **payload)
    kind = iseq[9]

    go_inside = -> {
      insns = iseq[13]

      execute_insns(insns, kind)
    }

    case kind
    when :top
      @frame_stack.enter_top(
        iseq: iseq,
        &go_inside
      )
    when :class
      @frame_stack.enter_class(
        iseq: iseq,
        parent_frame: current_frame,
        name: payload[:name],
        superclass: pop,
        &go_inside
      )
    when :method
      @frame_stack.enter_method(
        iseq: iseq,
        parent_frame: current_frame,
        arg_values: payload[:method_args],
        _self: payload[:_self],
        &go_inside
      )
    else
      binding.irb
    end
  end

  def execute_insns(insns, kind)
    @_insns = insns.dup

    loop do
      break if insns.empty?

      if @jump
        insns.shift until insns[0] == @jump
        @jump = nil
      end

      insn = insns.shift
      next_insn = insns[0]

      case insn
      when Integer
        case next_insn
        when :RUBY_EVENT_LINE
          current_frame.line = next_insn
          insns.shift
        when :RUBY_EVENT_END, :RUBY_EVENT_CLASS, :RUBY_EVENT_RETURN
          # noop
        when Array
          # ignore
        else
          binding.irb
        end
      when Array
        execute_insn(insn)
      end
    end
  rescue
    puts "--------------\nRest (for #{kind}):"
    insns.each { |insn| p insn }
    raise
  end

  def execute_insn(insn)
    p insn

    name, *payload = insn
    send(:"execute_#{name}", payload)
  end

  def push(object); @stack.push(object); end
  def pop;          @stack.pop;          end
  def reset_stack;  @stack = [];         end

  def current_frame; @frame_stack.top; end
  def current_self;  current_frame._self; end
  def current_nesting; current_frame.nesting; end
  def backtrace; @frame_stack.to_backtrace; end

  def _raise(klass, msg)
    e = klass.new(msg)
    e.set_backtrace(backtrace)
    raise e
  end

  def execute_putself(_)
    push(current_self)
  end

  def execute_putobject_INT2FIX_1_(_)
    push(1)
  end

  def execute_putobject((object))
    push(object)
  end

  def execute_opt_plus(_)
    arg = pop
    recv = pop
    push(recv + arg)
  end

  def execute_opt_send_without_block((options, _flag))
    args = []
    kwargs = {}

    if (kwarg_names = options[:kw_arg])
      kwarg_names.reverse_each do |kwarg_name|
        kwargs[kwarg_name] = pop
      end
    end

    args = options[:orig_argc].times.map { pop }.reverse
    if kwarg_names
      args << kwargs
    end
    recv = pop

    result =
      case (mid = options[:mid])
      when :'core#define_method'
        method_name, body_iseq = *args
        __define_method(method_name: method_name, body_iseq: body_iseq)
      else
        recv.send(mid, *args)
      end

    push(result)
  end

  def __define_method(method_name:, body_iseq:)
    _self = self
    define_on = DefinitionScope.new(current_frame)
    define_on.define_method(method_name) do |*method_args|
      _self.execute_iseq(body_iseq, _self: self, method_args: method_args)
    end
  end

  def execute_leave(args)
    # noop
  end

  def execute_putspecialobject(args)
    # noop (FrozenCore)
  end

  def execute_putnil(_)
    push(nil)
  end

  def execute_defineclass((name, iseq))
    execute_iseq(iseq, name: name)
  end

  def execute_pop(_)
    pop
  end

  def execute_opt_getinlinecache(_)
    # noop
  end

  def execute_opt_setinlinecache(_)
    # noop
  end

  def execute_getconstant((name))
    current_nesting.reverse_each do |mod|
      if mod.const_defined?(name)
        const = mod.const_get(name)
        push(const)
        return
      end
    end

    _raise NameError, "uninitialized constant #{name}"
  end

  def execute_putiseq((iseq))
    push(iseq)
  end

  def execute_duparray((array))
    push(array)
  end

  def execute_getlocal_WC_0((local_var_id))
    local = current_frame.locals.find(id: local_var_id)
    push(local.get)
  end

  def execute_setlocal_WC_0((local_var_id))
    value = pop
    local = current_frame.locals.find(id: local_var_id)

    if local.optarg && local.initialized
      # Already initialized optarg based on given arglist
      return
    end

    local.set(value)
  end

  def execute_checkkeyword((_unknown, kwoptarg_offset))
    kwoptarg_id = current_frame.kwoptarg_ids[kwoptarg_offset]
    value = current_frame.locals.find(id: kwoptarg_id).value
    push(!!value)
  end

  def execute_branchif((label))
    cond = pop
    if cond
      @jump = label
    end
  end

  def execute_expandarray((size, flag))
    if flag == 0
      array = pop

      case array
      when Array
        size.times { push(array.pop) }
      else
        binding.irb
      end
    else
      binding.irb
    end
  end

  def execute_dup(_)
    push(@stack.last.dup)
  end

  CHECK_TYPE = ->(klass, obj) {
    raise TypeError, "#{obj.inspect} is not a #{klass}" unless klass === obj
  }.curry

  RB_OBJ_TYPES = {
    0x00 => ->(obj) { binding.irb }, # RUBY_T_NONE

    0x01 => CHECK_TYPE[Object], # RUBY_T_OBJECT
    0x02 => ->(obj) { binding.irb }, # RUBY_T_CLASS
    0x03 => ->(obj) { binding.irb }, # RUBY_T_MODULE
    0x04 => ->(obj) { binding.irb }, # RUBY_T_FLOAT
    0x05 => CHECK_TYPE[String], # RUBY_T_STRING
    0x06 => ->(obj) { binding.irb }, # RUBY_T_REGEXP
    0x07 => ->(obj) { binding.irb }, # RUBY_T_ARRAY
    0x08 => ->(obj) { binding.irb }, # RUBY_T_HASH
    0x09 => ->(obj) { binding.irb }, # RUBY_T_STRUCT
    0x0a => ->(obj) { binding.irb }, # RUBY_T_BIGNUM
    0x0b => ->(obj) { binding.irb }, # RUBY_T_FILE
    0x0c => ->(obj) { binding.irb }, # RUBY_T_DATA
    0x0d => ->(obj) { binding.irb }, # RUBY_T_MATCH
    0x0e => ->(obj) { binding.irb }, # RUBY_T_COMPLEX
    0x0f => ->(obj) { binding.irb }, # RUBY_T_RATIONAL

    0x11 => ->(obj) { binding.irb }, # RUBY_T_NIL
    0x12 => ->(obj) { binding.irb }, # RUBY_T_TRUE
    0x13 => ->(obj) { binding.irb }, # RUBY_T_FALSE
    0x14 => ->(obj) { binding.irb }, # RUBY_T_SYMBOL
    0x15 => ->(obj) { binding.irb }, # RUBY_T_FIXNUM
    0x16 => ->(obj) { binding.irb }, # RUBY_T_UNDEF

    0x1a => ->(obj) { binding.irb }, # RUBY_T_IMEMO
    0x1b => ->(obj) { binding.irb }, # RUBY_T_NODE
    0x1c => ->(obj) { binding.irb }, # RUBY_T_ICLASS
    0x1d => ->(obj) { binding.irb }, # RUBY_T_ZOMBIE
    0x1e => ->(obj) { binding.irb }, # RUBY_T_MOVED

    0x1f => ->(obj) { binding.irb }, # RUBY_T_MASK
  }.freeze

  def execute_checktype((type))
    item_to_check = @stack.last
    check = RB_OBJ_TYPES.fetch(type) { raise "checktype - unknown type #{type}" }
    check.call(item_to_check)
  end

  def execute_concatstrings((count))
    strings = count.times.map { pop }.reverse
    push(strings.join)
  end

  def execute_newarray((size))
    array = size.times.map { pop }.reverse
    push(array)
  end
end
