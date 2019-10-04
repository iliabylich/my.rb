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

  def __log(string)
    print "-->" * @frame_stack.size
    print " "
    puts string
  end

  def execute_iseq(iseq, **payload)
    kind = iseq[9]

    go_inside = -> {
      insns = iseq[13]

      puts "\n\n"
      __log "--------- BEGIN #{current_frame.class} frame (#{current_frame.pretty_name}) ---------"

      result = execute_insns(insns, kind)
      __log "--------- END   #{current_frame.class} frame (#{current_frame.pretty_name}) ---------"
      puts "\n\n"

      result
    }

    case kind
    when :top
      @frame_stack.enter_top(
        iseq: iseq,
        &go_inside
      )
    when :class
      frame_name = iseq[5]
      superclass = pop

      case
      when frame_name.start_with?('<module')
        @frame_stack.enter_module(
          iseq: iseq,
          parent_frame: current_frame,
          name: payload[:name],
          &go_inside
        )
      when frame_name.start_with?('<class')
        @frame_stack.enter_class(
          iseq: iseq,
          parent_frame: current_frame,
          name: payload[:name],
          superclass: superclass,
          &go_inside
        )
      when frame_name == 'singleton class'
        @frame_stack.enter_sclass(
          iseq: iseq,
          parent_frame: current_frame,
          of: pop,
          &go_inside
        )
      else
        binding.irb
      end

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
    insns = insns.dup

    loop do
      break if insns.empty?

      if @jump
        __log "... #{insns.shift.inspect}" until insns[0] == @jump
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
      when [:leave]
        returning = pop
        __log "#{insn.inspect} (returning #{returning.inspect})"
        return returning
      when Array
        execute_insn(insn)
      when :RUBY_EVENT_END, :RUBY_EVENT_CLASS, :RUBY_EVENT_RETURN
        # skip
      when /\Alabel_/
        label = insn
        if current_frame.labels_to_skip.include?(label)
          __log "... #{label.inspect}"
          loop do
            break if insns.empty?
            next_insn = insns[0]

            if next_insn.is_a?(Symbol) && next_insn.to_s =~ /\Alabel_/
              break
            else
              __log "... #{insns.shift.inspect}"
            end
          end
        else
          __log label.inspect
          # just run it
        end
      end
    end
  rescue
    puts "--------------\nRest (for #{kind}):"
    insns.each { |insn| p insn }
    raise
  end

  def execute_insn(insn)
    name, *payload = insn

    case name
    when :defineclass
      __log [name, payload[0], '...omitted'].inspect
    when :putiseq
      __log [name, payload[0][5], '...omitted'].inspect
    else
      __log insn.inspect
    end

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

  def execute_putobject_INT2FIX_0_(_)
    push(0)
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

  #define VM_CALL_ARGS_SPLAT      (0x01 << VM_CALL_ARGS_SPLAT_bit)
  #define VM_CALL_ARGS_BLOCKARG   (0x01 << VM_CALL_ARGS_BLOCKARG_bit)
  #define VM_CALL_FCALL           (0x01 << VM_CALL_FCALL_bit)
  #define VM_CALL_VCALL           (0x01 << VM_CALL_VCALL_bit)
  #define VM_CALL_ARGS_SIMPLE     (0x01 << VM_CALL_ARGS_SIMPLE_bit)
  #define VM_CALL_BLOCKISEQ       (0x01 << VM_CALL_BLOCKISEQ_bit)
  #define VM_CALL_KWARG           (0x01 << VM_CALL_KWARG_bit)
  #define VM_CALL_KW_SPLAT        (0x01 << VM_CALL_KW_SPLAT_bit)
  #define VM_CALL_TAILCALL        (0x01 << VM_CALL_TAILCALL_bit)
  #define VM_CALL_SUPER           (0x01 << VM_CALL_SUPER_bit)
  #define VM_CALL_ZSUPER          (0x01 << VM_CALL_ZSUPER_bit)
  #define VM_CALL_OPT_SEND        (0x01 << VM_CALL_OPT_SEND_bit)
  VM_CALL_ARGS_SPLAT      = (0x01 << 0)
  VM_CALL_ARGS_BLOCKARG   = (0x01 << 1)
  VM_CALL_FCALL           = (0x01 << 2)
  VM_CALL_VCALL           = (0x01 << 3)
  VM_CALL_ARGS_SIMPLE     = (0x01 << 4)
  VM_CALL_BLOCKISEQ       = (0x01 << 5)
  VM_CALL_KWARG           = (0x01 << 6)
  VM_CALL_KW_SPLAT        = (0x01 << 7)
  VM_CALL_TAILCALL        = (0x01 << 8)
  VM_CALL_SUPER           = (0x01 << 9)
  VM_CALL_ZSUPER          = (0x01 << 10)
  VM_CALL_OPT_SEND        = (0x01 << 11)

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
      when :'core#define_singleton_method'
        recv, method_name, body_iseq = *args
        __define_singleton_method(recv: recv, method_name: method_name, body_iseq: body_iseq)
      when :'core#hash_merge_ptr'
        base = args.shift
        pairs = args.each_slice(2).to_a.to_h
        base.merge(pairs)
      when :'core#hash_merge_kwd'
        args.reduce(&:merge)
      else

        if (options[:flag] & VM_CALL_ARGS_SPLAT).nonzero? && kwarg_names.nil?
          *head, tail = args
          args = [*head, *tail]
        end

        recv.send(mid, *args)
      end

    push(result)
  end

  def execute_send((options, _flag1, _flag2))
    binding.irb
  end

  def __define_method(method_name:, body_iseq:)
    _self = self
    define_on = DefinitionScope.new(current_frame)
    define_on.define_method(method_name) do |*method_args|
      _self.execute_iseq(body_iseq, _self: self, method_args: method_args)
    end
    method_name
  end

  def __define_singleton_method(recv:, method_name:, body_iseq:)
    _self = self
    recv.define_singleton_method(method_name) do |*method_args|
      _self.execute_iseq(body_iseq, _self: self, method_args: method_args)
    end
    method_name
  end

  def execute_leave(args)
    @return = pop
  end

  def execute_putspecialobject(args)
    push(:FrozenCore)
  end

  def execute_putnil(_)
    push(nil)
  end

  # Handles class/module/sclass. Have no idea why
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
    push(iseq.freeze)
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

    unless current_frame.locals.declared?(id: local_var_id)
      current_frame.locals.declare(id: local_var_id)
    end

    local = current_frame.locals.find(id: local_var_id)
    local.set(value)
  end

  def execute_checkkeyword((_unknown, kwoptarg_offset))
    kwoptarg_id = current_frame.kwoptarg_ids[kwoptarg_offset]
    value = current_frame.locals.find(id: kwoptarg_id).value
    push(value != Locals::UNDEFINED)
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
        copy = array.dup
        size.times { push(copy.pop) }
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

  def execute_putstring((string))
    push(string)
  end

  def execute_splatarray((_flag))
    push(pop.to_a)
  end

  def execute_concatarray(_)
    last = pop
    first = pop
    push([*first, *last])
  end

  def execute_invokesuper((options, _flag1, _flag2))
    recv = current_frame._self
    mid = current_frame.name
    method = recv.method(mid).super_method
    args = options[:orig_argc].times.map { pop }.reverse

    if options[:flag] & VM_CALL_ARGS_SPLAT
      *head, tail = args
      args = [*head, *tail]
    end

    result = method.call(*args)
    push(result)
  end

  def execute_newhash((size))
    hash = size.times.map { pop }.reverse.each_slice(2).to_h
    push(hash)
  end

  def execute_swap(args)
    first = pop
    last = pop
    push(first)
    push(last)
  end

  def execute_opt_aref((options, _flag))
    args = options[:orig_argc].times.map { pop }.reverse
    recv = pop
    push(recv.send(:[], *args))
  end

  def execute_opt_mult((options, _flag))
    args = options[:orig_argc].times.map { pop }.reverse
    recv = pop
    push(recv.send(:*, *args))
  end
end
