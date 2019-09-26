$main = TOPLEVEL_BINDING.eval('self')

TopFrame = FrameClass.new do
  def initialize(**)
    self._self = $main
    self.nesting = [Object]
    self.locals = Locals.new
  end

  def pretty_name
    'TOP'
  end
end
