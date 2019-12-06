class Executor
  def vm; VM.instance; end

  def stack; vm.current_stack; end

  def push(object); stack.push(object)  end
  def pop;          stack.pop;          end
  def reset_stack;  stack = [];         end

  def current_frame;   vm.current_frame;   end
  def current_self;    vm.current_self;    end
  def current_nesting; vm.current_nesting; end

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
          raise VM::InternalError, 'unsupported'
        end

        recv.alias_method(new_method_name, existing_method_name)

        nil
      when :'core#undef_method'
        # noop
      else

        if (options[:flag] & VM_CALL_ARGS_SPLAT).nonzero? && kwarg_names.nil?
          *head, tail = args
          args = [*head, *tail]
        end

        recv.__send__(mid, *args)
      end

    push(result)
  end

  # always has a block, otherwise goes to opt_send_without_block
  def execute_send((options, _flag, block_iseq))
    _self = self
    mid = options[:mid]

    args = []
    kwargs = {}

    block =
      if block_iseq
        original_block_frame = self.current_frame
        proc do |*args, &block|
          VM.instance.execute(
            block_iseq,
              block_args: args,
              parent_frame: original_block_frame,
              before_eval: proc {
                if _self != self
                  # self switch, we should follow it
                  VM.instance.current_frame._self = self
                end
              },
              block: block
          )
        end
      elsif (implicit_block = pop)
        implicit_block
      else
        nil
      end

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

    if (options[:flag] & VM_CALL_ARGS_SPLAT).nonzero? && kwarg_names.nil?
      *head, tail = args
      args = [*head, *tail]
    end

    result = recv.__send__(mid, *args, &block)

    push(result)
  end

  def __define_method(method_name:, body_iseq:)
    parent_nesting = current_nesting
    define_on = MethodDefinitionScope.new(current_frame)

    define_on.define_method(method_name) do |*method_args, &block|
      ::VM.instance.execute(body_iseq, _self: self, method_args: method_args, block: block, parent_nesting: parent_nesting)
    end

    if current_frame.in_module_function_section
      current_frame._self.__send__(:module_function, method_name)
    end

    method_name
  end

  DEFINE_SINGLETON_METHOD = Kernel.instance_method(:define_singleton_method)

  def __define_singleton_method(recv:, method_name:, body_iseq:)
    parent_nesting = current_nesting
    DEFINE_SINGLETON_METHOD.bind(recv).call(method_name) do |*method_args, &block|
      ::VM.instance.execute(body_iseq, _self: self, method_args: method_args, block: block, parent_nesting: parent_nesting)
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
      raise VM::InternalError, 'dead'
    end
  end

  def execute_putnil(_)
    push(nil)
  end

  # Handles class/module/sclass. Have no idea why
  def execute_defineclass((name, iseq))
    superclass = pop

    returned =
      if name == :singletonclass
        # !? class << self
        of = pop
        VM.instance.execute(iseq, name: name, of: of)
      else
        # normal class/module
        scope = pop
        scope = current_frame.nesting.last if scope == :VM_SPECIAL_OBJECT_CONST_BASE
        VM.instance.execute(iseq, name: name, superclass: superclass, scope: scope)
      end

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

    vm._raise NameError, "uninitialized constant #{name}"
  end

  def execute_putiseq((iseq))
    push(iseq.freeze)
  end

  def execute_duparray((array))
    push(array)
  end

  def execute_getlocal((local_var_id, level))
    frame = level.times.inject(current_frame) { |f| f.parent_frame }
    local = frame.locals.find(id: local_var_id)
    value = local.get
    if value.equal?(Locals::UNDEFINED)
      value = nil
    end
    push(value)
  end

  def execute_getlocal_WC_0((local_var_id))
    local = current_frame.locals.find(id: local_var_id)
    value = local.get
    if value.equal?(Locals::UNDEFINED)
      value = nil
    end
    push(value)
  end

  def execute_getlocal_WC_1((local_var_id))
    local = current_frame.parent_frame.locals.find(id: local_var_id)
    value = local.get
    if value.equal?(Locals::UNDEFINED)
      value = nil
    end
    push(value)
  end

  def execute_setlocal_WC_0((local_var_id))
    value = pop
    locals = current_frame.locals

    unless locals.declared?(id: local_var_id)
      locals.declare(id: local_var_id)
    end

    local = locals.find(id: local_var_id)
    local.set(value)
  end

  def execute_setlocal_WC_1((local_var_id))
    value = pop
    locals = current_frame.parent_frame.locals

    unless locals.declared?(id: local_var_id)
      locals.declare(id: local_var_id)
    end

    local = locals.find(id: local_var_id)
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
      VM.instance.jump(label)
    end
  end

  def execute_branchunless((label))
    cond = pop
    unless cond
      VM.instance.jump(label)
    end
  end

  RESPOND_TO = Kernel.instance_method(:respond_to?)

  def __respond_to?(obj, meth, include_private = false)
    respond_to = RESPOND_TO.bind(obj)

    # check if it's possible to call #respond_to? normally
    if respond_to.call(:respond_to?)
      obj.respond_to?(meth, include_private)
    else
      # fallback to Kernel#respond_to?
      respond_to.call(meth, include_private)
    end
  end

  def coerce(obj, meth, expected_type)
    result = obj.__send__(meth)

    if result == nil
      return [obj]
    end

    unless expected_type === result
      raise TypeError, "#{meth} must return #{expected_type}"
    end

    result
  end

  def execute_expandarray((size, flag))
    array = pop

    if Array === array
      array = array.dup
    elsif __respond_to?(array, :to_ary, true)
      array = coerce(array, :to_ary, Array)
    else
      array = [array]
    end

    splat = (flag & 0x01)
    space_size = size + splat
    values_to_push = []

    if space_size == 0
      # no space left on stack
    elsif (flag & 0x02).nonzero?
      # postarg

      if size > array.size
        (size - array.size).times { values_to_push.push(nil) }
      end

      [size, array.size].min.times { values_to_push.push(array.pop) }

      if splat.nonzero?
        values_to_push.push(array.to_a)
      end

      values_to_push.each { |item| push(item) }
    else
      [size, array.size].min.times { values_to_push.push(array.shift) }

      if size > values_to_push.size
        (size - values_to_push.size).times { values_to_push.push(nil) }
      end

      if splat.nonzero?
        values_to_push.push(array.to_a)
      end

      values_to_push.reverse_each { |item| push(item) }
    end
  end

  def execute_dup(_)
    value = pop
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
    item_to_check = pop
    check = RB_OBJ_TYPES.fetch(type) { raise VM::InternalError, "checktype - unknown type #{type}" }
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
    value = pop
    if Array === value
      if value.instance_of?(Array)
        result = value.dup
      else
        result = Array[*value]
      end
    elsif value == nil
      result = value.to_a
    else
      if value.respond_to?(:to_a, true)
        result = value.send(:to_a)
        if result == nil
          result = [value]
        elsif !result.is_a?(Array)
          raise TypeError, "expected to_a to return an Array"
        end
      else
        result = [value]
      end
    end

    push(result)
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

    if (options[:flag] & VM_CALL_ARGS_SPLAT).nonzero?
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
    push(recv.__send__(:[], *args))
  end

  def execute_opt_aset((options, _flag))
    args = options[:orig_argc].times.map { pop }.reverse
    recv = pop
    push(recv.__send__(:[]=, *args))
  end

  def execute_opt_mult((options, _flag))
    args = options[:orig_argc].times.map { pop }.reverse
    recv = pop
    push(recv.__send__(:*, *args))
  end

  def execute_opt_length((options, _flag))
    args = options[:orig_argc].times.map { pop }.reverse
    recv = pop
    push(recv.__send__(:length, *args))
  end

  def execute_opt_eq((options, _flag))
    args = options[:orig_argc].times.map { pop }.reverse
    recv = pop
    push(recv.__send__(:==, *args))
  end

  def execute_opt_ltlt((options, _flag))
    item = pop
    list = pop
    push(list << item)
  end

  def execute_opt_gt(*)
    arg = pop
    recv = pop
    push(recv > arg)
  end

  def execute_getglobal((name))
    # unfortunately there's no introspection API atm
    push RubyRb::REAL_EVAL.bind(self).call(name.to_s)
  end

  def execute_setconstant((name))
    scope = pop
    scope = ConstantDefinitionScope.new(current_frame) if scope == :VM_SPECIAL_OBJECT_CONST_BASE

    value = pop
    scope.const_set(name, value)
  end

  GET_IVAR = Object.instance_method(:instance_variable_get)

  def execute_getinstancevariable((name, _flag))
    value = GET_IVAR.bind(current_frame._self).call(name)
    push(value)
  end

  SET_IVAR = Object.instance_method(:instance_variable_set)

  def execute_setinstancevariable((name, _flag))
    value = pop
    SET_IVAR.bind(current_frame._self).call(name, value)
  end

  def execute_getblockparam(args)
    push(current_frame.block)
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
    stack[-n-1] = stack.top
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
    stack.top.freeze
  end

  def execute_opt_neq(_)
    rhs = pop
    lhs = pop
    push(lhs != rhs)
  end

  def execute_branchnil((label))
    value = stack.top
    if value.nil?
      VM.instance.jump(label)
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
      when DefinedType::DEFINED_GVAR
        global_variables.include?(obj)
      else
        binding.irb
      end

    push(verdict)
  end

  def execute_jump((label))
    VM.instance.jump(label)
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
    RubyRb::REAL_EVAL.bind(self).call("#{name} = value")
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

  def execute_opt_case_dispatch((whens, else_label))
    value = pop
    whens.each_slice(2) do |(when_value, jump_to)|
      if value == when_value
        VM.instance.jump(jump_to)
        return
      end
    end

    VM.instance.jump(else_label)
  end

  VM_CHECKMATCH_TYPE_MASK = 0x03
  VM_CHECKMATCH_ARRAY     = 0x04
  VM_CHECKMATCH_TYPE_WHEN = 1
  VM_CHECKMATCH_TYPE_CASE = 2
  VM_CHECKMATCH_TYPE_RESCUE = 3

  def __checkmatch(pattern, target, match_type)
    if match_type == VM_CHECKMATCH_TYPE_WHEN
      return !!pattern
    end


    if match_type == VM_CHECKMATCH_TYPE_RESCUE
      if !pattern.is_a?(Module)
        raise TypeError, 'class or module required for rescue clause'
      end
    end

    if match_type == VM_CHECKMATCH_TYPE_CASE || match_type == VM_CHECKMATCH_TYPE_RESCUE
      return pattern.__send__(:===, target)
    end

    raise 'check_match: unreachable'
  end

  def execute_checkmatch((flag))
    pattern = pop
    target = pop

    match_type = flag & VM_CHECKMATCH_TYPE_MASK

    verdict =
      if (flag & VM_CHECKMATCH_ARRAY).nonzero?
        pattern.any? { |item_pattern| __checkmatch(item_pattern, target, match_type) }
      else
        __checkmatch(pattern, target, match_type)
      end

    push(verdict)
  end

  def execute_intern(args)
    push(pop.to_sym)
  end

  def execute_opt_mod(_)
    arg = pop
    recv = pop
    push(recv % arg)
  end

  def execute_opt_not(_)
    push(!pop)
  end

  def execute_newrange((flag))
    high = pop
    low = pop
    push(Range.new(low, high, flag == 1))
  end

  def execute_opt_empty_p(_)
    push(pop.empty?)
  end

  def execute_opt_size(_)
    push(pop.size)
  end

  def execute_opt_lt(_)
    arg = pop
    recv = pop
    push(recv < arg)
  end

  def execute_opt_le(_)
    arg = pop
    recv = pop
    push(recv <= arg)
  end

  def execute_invokeblock((options))
    args = options[:orig_argc].times.map { pop }.reverse

    frame = current_frame
    frame = frame.parent_frame until frame.can_yield?

    result = frame.block.call(*args)
    push(result)
  end

  def execute_opt_aset_with((key, options, flag))
    value = pop
    recv = pop
    push(recv[key] = value)
  end

  def execute_topn((n))
    push(stack[-n-1])
  end

  VM_THROW_NO_ESCAPE_FLAG = 0x8000
  VM_THROW_STATE_MASK = 0xff

  RUBY_TAG_NONE = 0x0
  RUBY_TAG_RETURN = 0x1
  RUBY_TAG_BREAK = 0x2
  RUBY_TAG_NEXT = 0x3
  RUBY_TAG_RETRY = 0x4
  RUBY_TAG_REDO = 0x5
  RUBY_TAG_RAISE = 0x6
  RUBY_TAG_THROW = 0x7
  RUBY_TAG_FATAL = 0x8
  RUBY_TAG_MASK = 0xf

  def _do_throw(throw_obj)
    return if throw_obj.nil?

    if throw_obj.is_a?(Exception)
      raise throw_obj
    else
      binding.irb
    end
  end

  def execute_throw((throw_state))
    state = throw_state & VM_THROW_STATE_MASK
    flag  = throw_state & VM_THROW_NO_ESCAPE_FLAG
    throw_obj = pop

    if state != 0
      # throw start
      case state
      when 1
        # return
        raise VM::ReturnError, throw_obj
      when 3
        # next inside rescue/ensure, inside pop_frame,
        # so current_frame is about to die

        frame = current_frame

        until frame.can_do_next?
          frame.exit!(:__unused)
          frame = frame.parent_frame
        end

        frame.returning = throw_obj
        frame.exit!(throw_obj)
      else
        binding.irb
      end
    else
      # throw continue
      _do_throw(throw_obj)
    end
  end

  def execute_reverse((n))
    n.times.map { pop }.each { |value| push(value) }
  end
end
