ClassFrame = FrameClass.new do
  def initialize(parent_frame:, name:, superclass:)
    define_on = DefinitionScope.new(parent_frame)

    klass =
      if define_on.const_defined?(name, false)
        define_on.const_get(name)
      else
        define_on.const_set(
          name,
          Class.new(superclass || Object)
        )
      end

    self._self = klass
    self.nesting = [*parent_frame.nesting, klass]
    self.locals = Locals.new
  end

  def pretty_name
    name
  end
end
