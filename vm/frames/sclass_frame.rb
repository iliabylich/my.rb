SClassFrame = FrameClass.new do
  def initialize(parent_frame:, of:)
    @parent_frame = parent_frame
    @of = of
  end

  def prepare
    sclass = @of.singleton_class

    self._self = sclass
    self.nesting = [*@parent_frame.nesting, sclass]
  end

  def pretty_name
    name
  end
end
