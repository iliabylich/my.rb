ClassFrame = FrameClass.new do
  def initialize(parent_frame:, name:, superclass:, scope:)
    @parent_frame = parent_frame
    @name = name
    @superclass = superclass
    @scope = scope
  end

  def prepare
    klass =
      if @scope.const_defined?(@name, false)
        @scope.const_get(@name)
      else
        @scope.const_set(
          @name,
          Class.new(@superclass || Object)
        )
      end

    self._self = klass
    self.nesting = [*@parent_frame.nesting, klass]
  end

  def pretty_name
    name
  end
end
