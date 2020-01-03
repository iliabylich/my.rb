class CategorizedArguments
  attr_reader :req, :opt, :rest, :post, :kw, :kwrest, :block

  def initialize(arg_names, args_info)
    @req = []
    @opt = []
    @rest = nil
    @post = []
    @kw = []
    @kwrest = []
    @block = nil

    parse!(arg_names.dup, args_info.dup)
  end

  KwReq = Struct.new(:name, keyword_init: true)
  InlineKwOpt = Struct.new(:name, :default, keyword_init: true)
  DynamicKwOpt = Struct.new(:name, keyword_init: true)

  def parse!(arg_names, args_info)
    (args_info[:lead_num] || 0).times do
      req << take_arg(arg_names)
    end

    opt_info = args_info[:opt].dup || []
    opt_info.shift
    opt_info.each do |label|
      opt << [take_arg(arg_names), label]
    end

    if args_info[:rest_start]
      @rest = take_arg(arg_names)
    end

    (args_info[:post_num] || 0).times do
      post << take_arg(arg_names)
    end

    (args_info[:keyword] || []).each do |kwarg|
      arg =
        case kwarg
        when Symbol
          KwReq.new(name: kwarg)
        when Array
          if kwarg.length == 2
            # inline default
            InlineKwOpt.new(name: kwarg[0], default: kwarg[1])
          else
            # complex default, set in the iseq
            DynamicKwOpt.new(name: kwarg[0])
          end
        else
          raise VM::InternalError, "Unknown kwarg #{kwarg}"
        end

      arg_names.delete(arg.name)
      kw << arg
    end

    if args_info[:kwrest]
      kwrest << take_arg(arg_names) << take_arg(arg_names)
    end

    if args_info[:block_start]
      @block = take_arg(arg_names)
    end
  end

  def take_arg(arg_names)
    arg_name_or_idx = arg_names.shift

    if arg_name_or_idx.is_a?(Integer)
      arg_name_or_idx += 1
    end

    arg_name_or_idx
  end
end
