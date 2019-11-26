EnsureFrame = FrameClass.new do
  attr_reader :parent_frame

  def initialize(parent_frame:)
    self._self = parent_frame._self
    self.nesting = parent_frame.nesting
    self.locals = Locals.new

    @parent_frame = parent_frame

    locals.declare(id: 3, name: :"\#$!")
    locals.find(id: 3).set(nil)
  end

  def pretty_name
    name
  end
end
