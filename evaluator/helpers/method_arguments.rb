class MethodArguments
  attr_reader :arg_names, :values, :locals, :args_info

  def initialize(iseq:, values:, locals:)
    @values = values.dup
    @locals = locals

    @arg_names = iseq[10].dup
    @args_info = iseq[11].dup
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

    rest_start = args_info[:rest_start]
    needs_rest = !rest_start.nil?

    post_num = args_info[:post_num] || 0
    post_start = args_info[:post_start]

    block_start = args_info[:block_start]

    kwdata = args_info[:keyword]
    needs_kw = (kwdata && kwdata.any?) || args_info[:kwrest]
    kwvalues = nil

    if needs_kw && kwvalues.nil?

      if values.last.is_a?(Hash)
        # consume
        kwvalues = values.last
      elsif kwdata.any? { |kw| kw.is_a?(Symbol) }
        raise "expected kwargs"
      else
        kwvalues = {}
      end
    end

    arg_names.each_with_index do |arg_name, idx|
      if req_args_count > 0
        # req pos argument
        arg_name += 1 if arg_name.is_a?(Integer)
        arg_value = values.shift
        locals.find(name: arg_name).set(arg_value)
        req_args_count -= 1
      elsif opt_info.any? && (rest_start ? idx < rest_start : true) && (post_start ? idx < post_start : true)
        if values.any?
          arg_value = values.shift
          locals.find(name: arg_name).set(arg_value)

          # skip default value initialization
          labels_to_skip << opt_info.first
        end

        opt_info.shift
      elsif needs_rest
        rest_value = values
        locals.find(name: arg_name).set(rest_value)
        needs_rest = false
      elsif post_num > 0
        arg_name += 1 if arg_name.is_a?(Integer)
        arg_value = values.shift
        locals.find(name: arg_name).set(arg_value)
        post_num -= 1
      elsif kwdata && (kwarg_info = kwdata.detect { |name| name == arg_name })
        # kwarg
        if kwvalues.key?(arg_name)
          arg_value = kwvalues.delete(arg_name)
          locals.find(name: arg_name).set(arg_value)
        else
          raise "missing kwarg #{arg_name.inspect}"
        end
      elsif kwdata && (kwoptarg_info = kwdata.detect { |(name,_)| name == arg_name })
        # kwoptarg
        local = locals.find(name: arg_name)

        if kwvalues.key?(arg_name)
          # value given
          arg_value = kwvalues.delete(arg_name)
          local.set(arg_value)
        elsif kwoptarg_info.length == 2
          # no value in arglist, but simple inlined default value in insn
          _, default = *kwoptarg_info
          local.set(default)

          # skip default value initialization
          labels_to_skip << opt_info.first
        else
          # no value in arglist, complex default value is set via insn in the future
        end

        opt_info.shift
      elsif kwdata
        # kwrestarg
        kwrest = kwvalues.reverse_each.to_a.to_h
        locals.find(id: arg_name).set(kwrest)
        kwdata = nil
      else

        # All other variables are getting post-processed via insns, that's the end
        break
      end
    end

    kwoptarg_ids = (@args_info[:keyword] || []).grep(Array).map { |name,| locals.find(name: name).id }
    [kwoptarg_ids, labels_to_skip]
  end
end
