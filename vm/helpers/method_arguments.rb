class MethodArguments
  attr_reader :arg_names, :values, :locals, :args_info

  def initialize(iseq:, values:, locals:)
    @values = values.dup
    @locals = locals
    @arg_names = iseq.lvar_names.dup

    @args_info = iseq.args_info.dup
  end

  def extract_arg_name_at(idx)
    result = arg_names.delete_at(idx)
    result += 1 if result.is_a?(Integer)
    result
  end

  def extract(arity_check: false)
    # Block argument
    if args_info[:block_start]
      arg_name = extract_arg_name_at(args_info[:block_start])
      arg_value = values.pop

      locals.find(name: arg_name).set(arg_value)
      VM.instance.__log { "blockarg: #{arg_name} = <block>" }
    end

    # Required positional args
    (args_info[:lead_num] || 0).times do
      arg_name = extract_arg_name_at(0)

      if arity_check && values.empty?
        raise ArgumentError, 'wrong number of arguments'
      end
      arg_value = values.shift

      locals.find(name: arg_name).set(arg_value)
      VM.instance.__log { "req: #{arg_name} = #{arg_value}" }
    end

    # Required keyword arguments
    (args_info[:keyword] || []).each do |kwarg|
      next unless kwarg.is_a?(Symbol)

      arg_name = kwarg
      arg_names.delete(arg_name)

      if (kw = values.last) && kw.is_a?(Hash)
        if kw.key?(arg_name)
          arg_value = kw.delete(arg_name)
          locals.find(name: arg_name).set(arg_value)
          VM.instance.__log { "kwreq: #{arg_name} = #{arg_value}" }
        else
          raise ArgumentError, "missing kwarg #{arg_name.inspect}"
        end
      else
        raise ArgumentError, "expected kwargs"
      end
    end

    # Required post positional arguments
    args_info[:post_start] -= args_info[:lead_num] if args_info[:post_start]

    post_start = args_info[:post_start] || 0
    post_num   = args_info[:post_num]   || 0

    has_kw = (args_info[:keyword] || []).any?

    keep_kw = has_kw && post_num < values.length

    (post_num - 1).downto(0) do |offset|
      arg_name = extract_arg_name_at(post_start + offset)
      if arity_check && values.empty?
        raise ArgumentError, 'wrong number of arguments'
      end

      if keep_kw
        arg_value = values.delete_at(values.length - 2)
      else
        arg_value = values.pop
      end

      locals.find(name: arg_name).set(arg_value)
      VM.instance.__log { "post: #{arg_name} = #{arg_value}" }
    end

    # Optional positional arguments

    opt_info = (args_info[:opt] || []).dup
    opt_info.shift

    opt_info.each do |label|
      arg_name = extract_arg_name_at(0)
      break if values.empty?

      arg_value = values.shift
      locals.find(name: arg_name).set(arg_value)

      VM.instance.__log { "opt: #{arg_name} = #{arg_value}" }
      VM.instance.jump(label)
    end

    # Optional keyword arguments

    (args_info[:keyword] || []).each do |kwarg|
      next unless kwarg.is_a?(Array)

      arg_name = kwarg[0]
      arg_names.delete(arg_name)

      local = locals.find(name: arg_name)

      if (kw = values.last) && kw.is_a?(Hash) && kw.key?(arg_name)
        # value given in the arglist
        arg_value = kw.delete(arg_name)
        VM.instance.__log { "kwopt: #{arg_name} = #{arg_value}" }
        local.set(arg_value)
      elsif kwarg.length == 2
        # inline primitive default value
        arg_value = kwarg[1]
        VM.instance.__log { "kwopt: #{arg_name} = #{arg_value}" }
        local.set(arg_value)
      else
        # there must be some insns to fill it
      end
    end

    # Rest keyword argument

    kwrest = nil
    if (kw = values.last) && kw.is_a?(Hash)
      if args_info[:kwrest]
        # consume it, but assign after handling restarg (to get the name)
        kwrest = values.pop
      elsif args_info[:keyword].any?
        symbol_keys = kw.keys.select { |k| k.is_a?(Symbol) }
        if symbol_keys.any?
          raise ArgumentError, "unknown keyword: #{symbol_keys.join(', ')}"
        end
      else
        # no kwargs/kwoptargs/kwrest
        # just keep it for the restarg
      end
    end

    # Rest positional argument

    if args_info[:rest_start]
      arg_name = extract_arg_name_at(0)
      arg_value = values

      locals.find(name: arg_name).set(arg_value)
      VM.instance.__log { "rest: #{arg_name} = #{arg_value.inspect}" }
    end

    # Rest keyword argument

    if args_info[:kwrest]
      arg_value = kwrest.reverse_each.to_a.to_h || {}

      if arg_names[0].is_a?(Integer)
        # internal variable that holds a copy of **kwrest
        arg_name = extract_arg_name_at(0)
        locals.find(name: arg_name).set(arg_value)
        VM.instance.__log { "kwrest(internal #{arg_name}): #{arg_value.inspect}" }
      end

      arg_name = arg_names.shift
      if arg_name.is_a?(Symbol)
        VM.instance.__log { "kwrest(#{arg_name}): #{arg_value.inspect}" }
        locals.find(name: arg_name).set(arg_value)
      else
        # **, no need to set it
      end

      locals.find(name: arg_name).set(arg_value)
      VM.instance.__log { "kwrest: #{arg_name} = #{arg_value.inspect}" }
    end

    if arity_check && values.any?
      raise ArgumentError, 'wrong number of arguments (too many)'
    end
  end
end
