RescueFrame = FrameClass.new do
  attr_reader :parent_frame, :caught

  def initialize(parent_frame:, caught:)
    self._self = parent_frame._self
    self.nesting = parent_frame.nesting
    self.locals = Locals.new

    @parent_frame = parent_frame
    @caught = caught

    locals.declare(id: 3, name: :"\#$!")
    locals.find(id: 3).set(caught)
  end

  def pretty_name
    name
  end
end
