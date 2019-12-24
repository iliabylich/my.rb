RescueFrame = FrameClass.new do
  attr_reader :parent_frame, :caught, :exit_to

  def initialize(parent_frame:, caught:, exit_to:)
    self._self = parent_frame._self
    self.nesting = parent_frame.nesting

    @parent_frame = parent_frame
    @caught = caught
    @exit_to = exit_to

    locals.declare(id: 3, name: :"\#$!")
    locals.find(id: 3).set(caught)
  end

  def pretty_name
    name
  end
end
