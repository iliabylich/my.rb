ClassFrame = FrameClass.new do
  def initialize(iseq:, parent_frame:, name:, superclass:)
    self.file, self.line, self.name = BasicFrameInfo.new(iseq)

    klass = Class.new(superclass || Object)
    define_on = DefinitionScope.new(parent_frame)
    define_on.const_set(name, klass)

    self._self = klass
    self.nesting = [*parent_frame.nesting, klass]
    self.locals = Locals.new
  end
end
