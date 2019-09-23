MethodFrame = FrameClass.new(
  :args_offset,
  :arg_names,
  :arg_values,
) do
  attr_reader :kwoptarg_ids

  def initialize(iseq:, parent_frame:, _self:, arg_values:)
    self.file, self.line, self.name = BasicFrameInfo.new(iseq)

    self.args_offset = iseq[4][:local_size]
    self.arg_names = iseq[10].dup
    self.arg_values = arg_values

    self._self = _self
    self.nesting = parent_frame.nesting
    self.locals = Locals.new

    # init arguments (without optargs and restarg)

    args_info = iseq[11].dup

    id = 3

    # this array contains all arguments mixed with utility vars to extract kwargs/mlhs
    iseq[10].reverse_each do |arg_name|
      arg_name += 1 if arg_name.is_a?(Integer)
      locals.declare(name: arg_name, id: id)
      id += 1
    end

    # 1. req
    req_args_count = args_info[:lead_num] || 0

    req_args_count.times do
      arg_name = arg_names.shift
      arg_name += 1 if arg_name.is_a?(Integer)
      arg_value = arg_values.shift
      locals.find(name: arg_name).set(arg_value)
    end

    # 2. prepare kwargs data
    if (kwdata = args_info[:keyword]) && kwdata.any?
      kwvalues = arg_values.pop

      unless kwvalues.is_a?(Hash)
        raise "expected kwargs"
      end
    end

    # 2. optargs
    optargs_count = args_info[:opt] ? args_info[:opt].size - 1 : 0

    optargs_count.times do
      arg_name = arg_names.shift
      arg_value = arg_values.shift
      locals.find(name: arg_name).set(arg_value, optarg: true)
    end

    if args_info[:rest_start]
      arg_name = arg_names.shift
      arg_value = arg_values
      locals.find(name: arg_name).set(arg_value)
    end

    # 2. all kwargs
    kwdata.each do |kwarg|
      case kwarg
      when Symbol # kwreq
        arg_name = kwarg
        if kwvalues.key?(arg_name)
          arg_value = kwvalues.delete(arg_name)
          locals.find(name: arg_name).set(arg_value)
        else
          raise "missing kwarg #{arg_name.inspect}"
        end
      when Array # kwoptarg
        arg_name, default = *kwarg
        arg_value = kwvalues.delete(arg_name)
        locals.find(name: arg_name).set(arg_value)
      else
        raise "Unknown kwarg data #{kwarg.inspect}"
      end
    end

    @kwoptarg_ids = args_info[:keyword].map { |name,| locals.find(name: name).id }

    # TODO: extract kwwrest

    # binding.irb
  end
end
