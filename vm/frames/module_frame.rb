ModuleFrame = FrameClass.new do
  def initialize(parent_frame:, name:)
    define_on = DefinitionScope.new(parent_frame)

    mod =
      if define_on.const_defined?(name)
        define_on.const_get(name)
      else
        define_on.const_set(name, Module.new)
      end

    self._self = mod
    self.nesting = [*parent_frame.nesting, mod]
    self.locals = Locals.new
  end

  def pretty_name
    name
  end
end
