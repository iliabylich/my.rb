class BacktraceEntry < String
  def initialize(frame)
    super("#{frame.file}:#{frame.line}:in `#{frame.name}'")
  end
end
