EvalFrame = FrameClass.new do
  attr_reader :parent_frame

  def initialize(parent_frame:, _self:)
    @parent_frame = parent_frame

    self._self = _self
    self.nesting = parent_frame.nesting
  end

  def prepare
    self.locals = EvalLocals.new(self)
  end

  def pretty_name
    "EVAL"
  end

  def eval?
    true
  end
end

# eval('code') gets compiled in the complpetely independent context
# and so it doessn't what is the frame offset for its locals
class EvalLocals < Locals
  def initialize(eval_frame)
    @eval_frame = eval_frame
    super(eval_frame.iseq.lvar_names)
  end

  def declared?(name: nil, id: nil)
    local = find_if_declared(name: name, id: id)
    !local.nil?
  end

  def find_if_declared(name: nil, id: nil)
    really_local = super

    # First check parent frames (by var name since ids don't match)
    var_name = name || (really_local.nil? ? nil : really_local.name)

    if !var_name
      # no name, there's no way to find it in the parent frame
      # so it's a really_local
      return really_local
    end

    frame = @eval_frame.parent_frame
    loop do
      if (parent_local = frame.locals.find_if_declared(name: var_name))
        return parent_local
      end

      case frame
      when MethodFrame, ClassFrame, ModuleFrame, SClassFrame
        # these frames do not look outside
        break
      when TopFrame
        # end of the chain
        break
      else
        # go up
        frame = frame.parent_frame
      end
    end

    # Parent frames don't declare it, so it's a local var
    really_local
  end
end
