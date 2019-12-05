ModuleFrame = FrameClass.new do
  def initialize(parent_frame:, name:)
    @parent_frame = parent_frame
    @name = name
  end

  def pretty_name
    name
  end

  def prepare
    define_on = DefinitionScope.new(@parent_frame)

    mod =
      if define_on.const_defined?(@name)
        define_on.const_get(@name)
      else
        define_on.const_set(@name, Module.new)
      end

    self._self = mod
    self.nesting = [*@parent_frame.nesting, mod]
  end
end
