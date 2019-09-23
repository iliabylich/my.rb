$main = TOPLEVEL_BINDING.eval('self')

TopFrame = Struct.new(
  :_self,
  :nesting,
  :locals,
  :file,
  :line,
  :name,
  keyword_init: true
) do
  def initialize(iseq:)
    self.file, self.line, self.name = BasicFrameInfo.new(iseq)

    self._self = $main
    self.nesting = [Object]
    self.locals = Locals.new
  end
end
