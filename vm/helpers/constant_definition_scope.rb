class ConstantDefinitionScope
  def self.new(frame)
    frame.nesting.last
  end
end
