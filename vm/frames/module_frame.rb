ModuleFrame = FrameClass.new do
  def initialize(parent_frame:, name:, scope:)
    @parent_frame = parent_frame
    @name = name
    @scope = scope
  end

  def pretty_name
    name
  end

  def prepare
    mod =
      if @scope.const_defined?(@name)
        result = @scope.const_get(@name)



        case result
        when Class
          raise TypeError, "#{@name} is not a module"
        when Module
          # ok
        else
          raise TypeError, "#{@name} is not a module"
        end

        result
      else
        @scope.const_set(@name, Module.new)
      end

    self._self = mod
    self.nesting = [*@parent_frame.nesting, mod]
  end
end
