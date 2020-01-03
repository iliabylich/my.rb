BlockFrame = FrameClass.new do
  attr_accessor :is_lambda
  attr_reader :kwoptarg_ids, :parent_frame

  attr_reader :block

  attr_reader :arg_values

  def initialize(parent_frame:, arg_values:, block:)
    self._self = parent_frame._self
    self.nesting = parent_frame.nesting

    @block = block
    @parent_frame = parent_frame
    @arg_values = arg_values
  end

  def prepare
    if expand_single_array_argument?
      arg = @arg_values[0]

      if arg.is_a?(Array)
        values = arg
      else
        case (to_ary = arg.to_ary)
        when nil
          values = [arg]
        when Array
          values = to_ary
        else
          raise TypeError, "can't convert #{arg.class} to Array (#{arg.class}#to_ary gives #{to_ary.class})"
        end
      end
    else
      values = @arg_values
    end

    MethodArguments.new(
      iseq: iseq,
      values: values,
      locals: locals,
      block: iseq.args_info[:block_start] ? block : nil
    ).extract(arity_check: is_lambda)

    @kwoptarg_ids = (iseq.args_info[:keyword] || []).grep(Array).map { |name,| locals.find(name: name).id }
  end

  def pretty_name
    name
  end

  def can_do_next?
    true
  end

  def can_do_break?
    true
  end

  private

  def expand_single_array_argument?
    return false if iseq.args_info[:ambiguous_param0]
    return false if arg_values.length != 1
    first_element = arg_values[0]
    return false if !first_element.is_a?(Array) && !first_element.respond_to?(:to_ary)
    lead_num = iseq.args_info[:lead_num] || 0
    opt      = iseq.args_info[:opt] || []
    return false if lead_num == 0 && opt.empty?
    true
  end
end
