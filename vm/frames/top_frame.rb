$main = TOPLEVEL_BINDING.eval('self')

TopFrame = FrameClass.new do
  def initialize(**)
    self._self = $main
    self.nesting = [Object]
  end

  def pretty_name
    "TOP #{file}"
  end
end
