require_relative './categorized_arguments'

class MethodArguments
  attr_reader :args, :values, :locals, :block

  def initialize(iseq:, values:, locals:, block:)
    @values = values.dup
    @locals = locals
    @block = block
    @iseq = iseq

    @args = CategorizedArguments.new(
      iseq.lvar_names,
      iseq.args_info
    )
  end

  def extract(arity_check: false)
    # Required positional args
    args.req.each do |name|
      if arity_check && values.empty?
        raise ArgumentError, 'wrong number of arguments (too few)'
      end

      value = values.shift
      locals.find(name: name).set(value)
      VM.instance.__log { "req: #{name} = #{value}" }
    end

    __kw_initializers = []

    if values.length > args.post.length
      kw = values.last
    else
      kw = nil
    end

    if kw.respond_to?(:to_hash)
      kw = values[values.length - 1] = kw.to_hash
    end

    if kw.is_a?(Hash)
      kw = values[values.length - 1] = kw.dup
    end

    args.kw.each do |kwarg|
      name = kwarg.name

      case kwarg
      when CategorizedArguments::KwReq
        unless kw.is_a?(Hash)
          raise ArgumentError, 'expected kwargs'
        end

        if kw.key?(kwarg.name)
          value = kw.delete(kwarg.name)
          __kw_initializers << [:kwreq, name, value]
          # -> {
          #   locals.find(name: name).set(value)
          #   VM.instance.__log { "kwreq: #{name} = #{value.inspect}" }
          # }
        else
          raise ArgumentError, "missing keyword #{name.inspect}"
        end
      when CategorizedArguments::InlineKwOpt
        if kw.is_a?(Hash) && kw.key?(name)
          value = kw.delete(name)
        else
          value = kwarg.default
        end
        __kw_initializers << [:kwopt, name, value]
        # -> {
        #   locals.find(name: name).set(value)
        #   VM.instance.__log { "kwopt: #{name} = #{value.inspect}" }
        # }
      when CategorizedArguments::DynamicKwOpt
        if kw.is_a?(Hash) && kw.key?(name)
          value = kw.delete(name)
          # -> {
          #   locals.find(name: name).set(value)
          #   VM.instance.__log { "kwopt: #{name} = #{value.inspect}" }
          # }
          __kw_initializers << [:kwopt, name, value]
        else
          # complex default value,
          # there must be insns to set it
        end
      else
        raise VM::InternalError, "Unsupported kwarg type #{kwarg.class}"
      end
    end

    if (kwrest_names = args.kwrest) && kwrest_names.any?
      if kw.is_a?(Hash)
        symbols, strings = kw.partition { |(k)| k.is_a?(Symbol) }.map(&:to_h)
        value = symbols
        kw = values[values.length - 1] = strings
      else
        value = {}
      end

      kwrest_names.each do |name|
        next if name.nil?
        __kw_initializers << [:kwrest, name, value]
        # locals.find(name: name).set(value)
        # VM.instance.__log { "kwrest(#{name}): #{value.inspect}" }
      end
    end

    if __kw_initializers.any? && kw.is_a?(Hash)
      extra_kws = kw.keys.grep(Symbol)
      if extra_kws.any?
        raise ArgumentError, "unknown keywords: #{extra_kws.join(', ')}"
      end
      if kw.empty?
        # all consumed
        values.pop
      end
    end

    # Optional positional args
    args.opt.each do |(name, label)|
      break if values.length <= args.post.count

      value = values.shift
      locals.find(name: name).set(value)

      VM.instance.__log { "opt: #{name} = #{value}" }
      VM.instance.jump(label)
    end

    # Rest positional argument
    if (name = args.rest)
      value = values.first(values.length - args.post.length)
      @values = values.last(args.post.length)

      locals.find(name: name).set(value)
      VM.instance.__log { "rest: #{name} = #{value.inspect}" }
    end

    # Required post positional arguments
    args.post.each do |name|
      if values.empty?
        raise ArgumentError, 'Broken arguments, cannot extract required argument'
      end

      value = values.shift
      locals.find(name: name).set(value)
      VM.instance.__log { "post: #{name} = #{value}" }
    end

    __kw_initializers.each do |kind, name, value|
        locals.find(name: name).set(value)
        VM.instance.__log { "#{kind}: #{name} = #{value.inspect}" }
    end

    if arity_check && values.any?
      raise ArgumentError, 'wrong number of arguments (too many)'
    end

    # if has_kw && kw.is_a?(Hash) && kw.any?
    #   extra_kw = kw.keys.grep(Symbol)
    #   if reusing_kw
    #     if extra_kw.any?
    #       raise ArgumentError, "unknown keywords: #{extra_kw.join(', ')}"
    #     end
    #   else
    #     binding.irb
    #   end
    # end
  end
end
