class MethodArguments
  attr_reader :arg_names, :values, :locals, :args_info

  def initialize(iseq:, values:, locals:)
    @values = values.dup
    @locals = locals

    @arg_names = iseq.arg_names.dup
    @args_info = iseq.args_info.dup
  end

  def extract
    labels_to_skip = []

    # this array contains all arguments mixed with utility vars to extract kwargs/mlhs
    arg_names.reverse_each.with_index(3) do |arg_name, idx|
      arg_name += 1 if arg_name.is_a?(Integer) # virtual attribute that holds mlhs value
      locals.declare(name: arg_name, id: idx)
    end

    req_args_count = args_info[:lead_num] || 0

    opt_info = (args_info[:opt] || []).dup
    opt_info.shift

    rest_start = args_info[:rest_start]
    needs_rest = !rest_start.nil?

    post_num = args_info[:post_num] || 0
    post_start = args_info[:post_start]

    block_start = args_info[:block_start]

    kwdata = args_info[:keyword] || []
    needs_kw = kwdata.any? || args_info[:kwrest]
    kwvalues = nil

    if args_info[:block_start]
      # inline block (like in css)
      block_name = arg_names.last
      block = values.pop

      locals.find(name: block_name).set(block)
    end

    if needs_kw && kwvalues.nil?
      if values.last.is_a?(Hash)
        # consume
        kwvalues = values.pop
      elsif kwdata.any? { |kw| kw.is_a?(Symbol) }
        raise ArgumentError, "expected kwargs"
      else
        kwvalues = {}
      end
    end

    req_args_count.times do
      arg_name = arg_names.shift
      arg_name += 1 if arg_name.is_a?(Integer)
      arg_value = values.shift
      locals.find(name: arg_name).set(arg_value)
      VM.instance.__log("req: #{arg_name} = #{arg_value}")
    end

    opt_info.each do |label|
      arg_name = arg_names.shift
      next if values.none? || values.length < post_num
      arg_value = values.shift
      locals.find(name: arg_name).set(arg_value)
      VM.instance.__log("opt: #{arg_name} = #{arg_value}")
      VM.instance.jump(label)
    end

    if rest_start
      arg_name = arg_names.shift
      arg_value = values[0..-(post_num + 1)]
      locals.find(name: arg_name).set(arg_value)
      VM.instance.__log("rest: #{arg_name} = #{arg_value.inspect}")

      @values = values[post_num..-1] || []
    end

    post_num.times do
      arg_name = arg_names.shift
      arg_name += 1 if arg_name.is_a?(Integer)
      arg_value = values.shift
      locals.find(name: arg_name).set(arg_value)
      VM.instance.__log("post: #{arg_name} = #{arg_value}")
    end

    kwdata.each do |kwarg|
      case kwarg
      when Array
        # kwopt
        arg_name = kwarg[0]
        arg_names.delete(arg_name)

        local = locals.find(name: arg_name)

        if kwvalues.key?(arg_name)
          # value given
          arg_value = kwvalues.delete(arg_name)
          VM.instance.__log("kwopt: #{arg_name} = #{arg_value}")
          local.set(arg_value)
        elsif kwarg.length == 2
          # inline default value
          arg_value = kwarg[1]
          VM.instance.__log("kwopt: #{arg_name} = #{arg_value}")
          local.set(arg_value)
        else
          # there must be some insns to fill it
        end
      else
        # kwreq
        arg_name = kwarg
        arg_names.delete(arg_name)

        if kwvalues.key?(arg_name)
          arg_value = kwvalues.delete(arg_name)
          locals.find(name: arg_name).set(arg_value)
          VM.instance.__log("kwreq: #{arg_name} = #{arg_value}")
        else
          raise ArgumentError, "missing kwarg #{arg_name.inspect}"
        end
      end
    end

    if args_info[:kwrest]
      arg_value = kwvalues.reverse_each.to_a.to_h

      if arg_names[0].is_a?(Integer)
        # internal variable that holds a copy of **kwrest
        arg_name = arg_names.shift
        arg_name += 1 if arg_name.is_a?(Integer)
        locals.find(name: arg_name).set(arg_value)
        VM.instance.__log("kwrest(internal #{arg_names}): #{arg_value.inspect}")
      end

      arg_name = arg_names.shift
      locals.find(name: arg_name).set(arg_value)

      VM.instance.__log("kwreq: #{arg_name} = #{arg_value.inspect}")
    end
  end
end
