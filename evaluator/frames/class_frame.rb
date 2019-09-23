ClassFrame = FrameClass.new do
  def initialize(parent_frame:, name:, superclass:)
    klass = Class.new(superclass || Object)
    define_on = DefinitionScope.new(parent_frame)
    define_on.const_set(name, klass)

    self._self = klass
    self.nesting = [*parent_frame.nesting, klass]
    self.locals = Locals.new
  end
end
