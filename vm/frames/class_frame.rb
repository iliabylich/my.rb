ClassFrame = FrameClass.new do
  def initialize(parent_frame:, name:, superclass:, scope:)
    @parent_frame = parent_frame
    @name = name
    @superclass = superclass
    @scope = scope
  end

  def prepare
    case @scope
    when Class, Module
      # ok
    else
      raise TypeError, "#{@scope} is not a class/module"
    end

    klass =
      if @scope.const_defined?(@name, false)
        result = @scope.const_get(@name)

        case result
        when Class
          # ok
        else
          raise TypeError, "#{@name} is not a class"
        end

        if @superclass && result.superclass != @superclass
          raise TypeError, 'superclass mismatch'
        end

        result
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
