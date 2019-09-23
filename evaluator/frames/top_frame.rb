$main = TOPLEVEL_BINDING.eval('self')

TopFrame = FrameClass.new do
  def initialize(iseq:)
    self.file, self.line, self.name = BasicFrameInfo.new(iseq)

    self._self = $main
    self.nesting = [Object]
    self.locals = Locals.new
  end
end
