require_relative './evaluator/frames'

class Evaluator
  def initialize
    @stack = []
    @stack.singleton_class.prepend(Module.new {
      def pop
        if length == 0
          raise 'stack is empty'
        end
        super
      end
    })
    @frame_stack = FrameStack.new

    @jump = nil
  end

  def self.instance
    @_instance ||= new
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

      header = "#{current_frame.class} frame (#{current_frame.pretty_name} in #{current_frame.file}:#{current_frame.line})"

      puts "\n\n"
      __log "--------- BEGIN #{header} ---------"

      result = execute_insns(insns, kind)
      __log "--------- END   #{header} ---------"
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
          superclass: payload[:superclass],
          &go_inside
        )
      when frame_name == 'singleton class'
        @frame_stack.enter_sclass(
          iseq: iseq,
          parent_frame: current_frame,
          of: payload[:cbase],
          &go_inside
        )
      else
        binding.irb
      end

    when :method
      @frame_stack.enter_method(
        iseq: iseq,
        parent_nesting: payload[:parent_nesting],
        _self: payload[:_self],
        arg_values: payload[:method_args],
        block: payload[:block],
        &go_inside
      )
    when :block
      @frame_stack.enter_block(
        iseq: iseq,
        parent_frame: payload[:parent_frame],
        block_args: payload[:block_args],
        &go_inside
      )
    else
      binding.irb
    end
  end

  def execute_insns(insns, kind)
    stack_size_before = @stack.size

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
          current_frame.line = insn
          insns.shift
        when :RUBY_EVENT_END, :RUBY_EVENT_CLASS, :RUBY_EVENT_RETURN, :RUBY_EVENT_B_CALL, :RUBY_EVENT_B_RETURN
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
    puts "--------------\nRest (for #{kind} in #{current_frame.file}):"
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
    mid = options[:mid]

    if mid == :module_function && options[:orig_argc] == 0
      current_frame.open_module_function_section!
      push(nil)
      return
    end

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
      case mid
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
      when :'core#set_method_alias'
        recv, new_method_name, existing_method_name = *args

        case recv
        when :VM_SPECIAL_OBJECT_CBASE
          recv = current_frame._self
        else
          raise 'unsupported'
        end

        recv.alias_method(new_method_name, existing_method_name)

        nil
      else

        if (options[:flag] & VM_CALL_ARGS_SPLAT).nonzero? && kwarg_names.nil?
          *head, tail = args
          args = [*head, *tail]
        end

        recv.send(mid, *args)
      end

    push(result)
  end

  # always has a block, otherwise goes to opt_send_without_block
  def execute_send((options, _flag, block_iseq))
    _self = self
    mid = options[:mid]

    args = []
    kwargs = {}

    if (kwarg_names = options[:kw_arg])
      kwarg_names.reverse_each do |kwarg_name|
        kwargs[kwarg_name] = pop
      end
    end

    block =
      if block_iseq
        original_block_frame = self.current_frame
        proc { |*args| _self.execute_iseq(block_iseq, block_args: args, parent_frame: original_block_frame) }
      else
        pop.to_proc
      end

    args = options[:orig_argc].times.map { pop }.reverse
    if kwarg_names
      args << kwargs
    end

    recv = pop

    if (options[:flag] & VM_CALL_ARGS_SPLAT).nonzero? && kwarg_names.nil?
      *head, tail = args
      args = [*head, *tail]
    end

    result = recv.send(mid, *args, &block)

    push(result)
  end

  def __define_method(method_name:, body_iseq:)
    _self = self
    parent_nesting = current_nesting
    define_on = DefinitionScope.new(current_frame)

    define_on.define_method(method_name) do |*method_args, &block|
      _self.execute_iseq(body_iseq, _self: self, method_args: method_args, block: block, parent_nesting: parent_nesting)
    end

    if current_frame.in_module_function_section
      current_frame._self.send(:module_function, method_name)
    end

    method_name
  end

  def __define_singleton_method(recv:, method_name:, body_iseq:)
    _self = self
    parent_nesting = current_nesting
    recv.define_singleton_method(method_name) do |*method_args, &block|
      _self.execute_iseq(body_iseq, _self: self, method_args: method_args, block: block, parent_nesting: parent_nesting)
    end
    method_name
  end

  def execute_putspecialobject((type))
    case type
    when 1
      push(:FrozenCore)
    when 2
      push(:VM_SPECIAL_OBJECT_CBASE)
    when 3
      push(:VM_SPECIAL_OBJECT_CONST_BASE)
    else
      raise 'dead'
    end
  end

  def execute_putnil(_)
    push(nil)
  end

  # Handles class/module/sclass. Have no idea why
  def execute_defineclass((name, iseq))
    superclass = pop
    cbase = pop
    cbase = DefinitionScope.new(current_frame) if cbase == :VM_SPECIAL_OBJECT_CONST_BASE

    returned = execute_iseq(iseq, name: name, cbase: cbase, superclass: superclass)
    push(returned)
  end

  def execute_pop(_)
    pop
  end

  def execute_opt_getinlinecache(_)
    push(:INLINE_CACHE)
    # noop
  end

  def execute_opt_setinlinecache(_)
    # noop
  end

  def execute_getconstant((name))
    inline_cache = pop

    search_in = inline_cache == :INLINE_CACHE ? current_nesting.reverse : [inline_cache]

    search_in.each do |mod|
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

  def execute_getlocal_WC_1((local_var_id))
    local = current_frame.parent_frame.locals.find(id: local_var_id)
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

  def execute_branchunless((label))
    cond = pop
    unless cond
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
    value = @stack.pop
    push(value); push(value)
  end

  CHECK_TYPE = ->(klass, obj) {
    klass === obj
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
    item_to_check = @stack.pop
    check = RB_OBJ_TYPES.fetch(type) { raise "checktype - unknown type #{type}" }
    result = check.call(item_to_check)
    push(result)
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

  def execute_opt_aset((options, _flag))
    args = options[:orig_argc].times.map { pop }.reverse
    recv = pop
    push(recv.send(:[]=, *args))
  end

  def execute_opt_mult((options, _flag))
    args = options[:orig_argc].times.map { pop }.reverse
    recv = pop
    push(recv.send(:*, *args))
  end

  def execute_opt_length((options, _flag))
    args = options[:orig_argc].times.map { pop }.reverse
    recv = pop
    push(recv.send(:length, *args))
  end

  def execute_opt_eq((options, _flag))
    args = options[:orig_argc].times.map { pop }.reverse
    recv = pop
    push(recv.send(:==, *args))
  end

  def execute_opt_ltlt((options, _flag))
    item = pop
    list = pop
    push(list << item)
  end

  def execute_getglobal((name))
    # unfortunately there's no introspection API atm
    push eval(name.to_s)
  end

  def execute_setconstant((name))
    scope = pop
    scope = DefinitionScope.new(current_frame) if scope == :VM_SPECIAL_OBJECT_CONST_BASE

    value = pop
    scope.const_set(name, value)
  end

  def execute_getinstancevariable((name, _flag))
    value = current_frame._self.instance_variable_get(name)
    push(value)
  end

  def execute_setinstancevariable((name, _flag))
    value = pop
    current_frame._self.instance_variable_set(name, value)
  end

  def execute_getblockparamproxy(args)
    push(current_frame.block)
  end

  def execute_nop(*); end

  def execute_duphash((hash))
    push(hash.dup)
  end

  def execute_dupn((n))
    values = n.times.map { pop }.reverse
    2.times { values.each { |value| push(value) } }
  end

  def execute_setn((n))
    @stack[-n-1] = @stack.last
  end

  def execute_tostring(*)
    str = pop
    obj = pop
    if str != obj.to_s
      # TODO: must be some raise here
      # if to_s failed to convert an object
      binding.irb
    end
    push(str)
  end

  def execute_freezestring((_flag))
    @stack.last.freeze
  end

  def execute_opt_neq(_)
    rhs = pop
    lhs = pop
    push(lhs != rhs)
  end

  def execute_branchnil((label))
    value = @stac.last
    if value.nil?
      @jump = label
    end
  end

  def execute_setclassvariable((name))
    value = pop
    current_frame._self.class_variable_set(name, value)
  end

  module DefinedType
    DEFINED_NOT_DEFINED = 0
    DEFINED_NIL = 1
    DEFINED_IVAR = 2
    DEFINED_LVAR = 3
    DEFINED_GVAR = 4
    DEFINED_CVAR = 5
    DEFINED_CONST = 6
    DEFINED_METHOD = 7
    DEFINED_YIELD = 8
    DEFINED_ZSUPER = 9
    DEFINED_SELF = 10
    DEFINED_TRUE = 11
    DEFINED_FALSE = 12
    DEFINED_ASGN = 13
    DEFINED_EXPR = 14
    DEFINED_IVAR2 = 15
    DEFINED_REF = 16
    DEFINED_FUNC = 17
  end

  def execute_defined((defined_type, obj, needstr))
    context = pop # unused in some branches

    verdict =
      case defined_type
      when DefinedType::DEFINED_IVAR
        ivar_name = obj
        current_frame._self.instance_variable_defined?(ivar_name)
      when DefinedType::DEFINED_CONST
        const_name = obj || current_nesting.last
        context ||= Object
        context.const_defined?(obj)
      else
        binding.irb
      end

    push(verdict)
  end

  def execute_jump((label))
    @jump = label
  end

  def execute_adjuststack((n))
    n.times { pop }
  end

  def execute_opt_div(_)
    arg = pop
    recv = pop
    push(recv / arg)
  end

  def execute_opt_regexpmatch2(_)
    arg = pop
    recv = pop
    push(recv =~ arg)
  end

  def execute_opt_aref_with((key, options, _flag))
    recv = pop
    push(recv[key])
  end

  def execute_opt_ge(args)
    arg = pop
    recv = pop
    push(recv >= arg)
  end

  def execute_setglobal((name))
    # there's no way to set a gvar by name/value
    # but eval can reference locals
    value = pop
    eval("#{name} = value")
  end

  def execute_opt_and(_)
    arg = pop
    recv = pop
    push(recv & arg)
  end

  def execute_opt_minus(_)
    arg = pop
    recv = pop
    push(recv - arg)
  end

  def execute_toregexp((kcode, size))
    source = size.times.map { pop }.reverse.join
    push(Regexp.new(source, kcode))
  end

  def execute_opt_str_freeze((str, _options, _flag))
    push(str.freeze)
  end
end
