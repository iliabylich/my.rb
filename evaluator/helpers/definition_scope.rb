class DefinitionScope
  def self.new(frame)
    case frame._self
    when Class, Module
      frame._self
    when $main
      Object
    else
      frame._self.singleton_class
    end
  end
end
