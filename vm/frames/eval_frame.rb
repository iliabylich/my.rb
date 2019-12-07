EvalFrame = FrameClass.new do
  attr_reader :parent_frame

  def initialize(parent_frame:, _self:)
    @parent_frame = parent_frame

    self._self = _self
    self.nesting = parent_frame.nesting
  end

  def pretty_name
    "EVAL"
  end

  def eval?
    true
  end
end
