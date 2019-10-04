SClassFrame = FrameClass.new do
  def initialize(parent_frame:, of:)
    sclass = of.singleton_class

    self._self = sclass
    self.nesting = [*parent_frame.nesting, sclass]
    self.locals = Locals.new
  end

  def pretty_name
    name
  end
end
