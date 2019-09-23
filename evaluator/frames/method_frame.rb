MethodFrame = FrameClass.new do
  attr_reader :kwoptarg_ids

  def initialize(parent_frame:, _self:, arg_values:)
    self._self = _self
    self.nesting = parent_frame.nesting
    self.locals = Locals.new

    arg_names = _iseq[10].dup

    # init arguments (without optargs and restarg)

    args_info = _iseq[11].dup

    id = 3

    # this array contains all arguments mixed with utility vars to extract kwargs/mlhs
    arg_names.reverse_each do |arg_name|
      arg_name += 1 if arg_name.is_a?(Integer)
      locals.declare(name: arg_name, id: id)
      id += 1
    end

    req_args_count = args_info[:lead_num]
    opt_info = args_info[:opt].dup
    rest_start = args_info[:rest_start]
    kwdata = args_info[:keyword]
    needs_kw = kwdata && kwdata.any?
    kwvalues = nil
    needs_rest = !rest_start.nil?

    if needs_kw && kwvalues.nil?
      kwvalues = arg_values.pop

      unless kwvalues.is_a?(Hash)
        raise "expected kwargs"
      end
    end

    arg_names.each_with_index do |arg_name, idx|
      if req_args_count && req_args_count > 0
        # req argument
        arg_name += 1 if arg_name.is_a?(Integer)
        arg_value = arg_values.shift
        locals.find(name: arg_name).set(arg_value)
        req_args_count -= 1
      elsif opt_info.any? && rest_start && idx < rest_start
        if arg_values.any?
          arg_value = arg_values.shift
          locals.find(name: arg_name).set(arg_value)

          # skip default value initialization
          labels_to_skip << opt_info.first
        end

        opt_info.shift
      elsif needs_rest
        rest_value = arg_values
        locals.find(name: arg_name).set(rest_value)
        needs_rest = false
      else
        # kwreq/kwopt/kwres
        kwarg_info = kwdata.detect { |name| name == arg_name }
        kwoptarg_info = kwdata.detect { |(name,_)| name == arg_name }

        if kwarg_info
          # kwarg
          if kwvalues.key?(arg_name)
            arg_value = kwvalues.delete(arg_name)
            locals.find(name: arg_name).set(arg_value)
          else
            raise "missing kwarg #{arg_name.inspect}"
          end
        elsif kwoptarg_info
          # kwoptarg
          local = locals.find(name: arg_name)

          if kwvalues.key?(arg_name)
            # value given
            arg_value = kwvalues.delete(arg_name)
            local.set(arg_value)

            # skip default value initialization
            # labels_to_skip << opt_info.first
          elsif kwoptarg_info.length == 2
            # no value in arglist, but simple inlined default value
            _, default = *kwoptarg_info
            local.set(default)

            # skip default value initialization
            labels_to_skip << opt_info.first
          else
            # no value in arglist, complex default value is set via insn in the future
          end

          opt_info.shift
        else
          value = kwvalues
          locals.find(id: arg_name).set(value)

          # All other variables are getting post-processed via insns
          break
        end
      end
    end

    @kwoptarg_ids = (args_info[:keyword] || []).grep(Array).map { |name,| locals.find(name: name).id }
  end
end
