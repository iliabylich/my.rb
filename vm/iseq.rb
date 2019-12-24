class ISeq
  attr_reader :insns
  attr_reader :rescue_handlers
  attr_reader :ensure_handlers

  def initialize(ruby_iseq)
    @ruby_iseq = ruby_iseq
    reset!
    setup_rescue_handlers!
    setup_ensure_handlers!
  end

  def initially_had_insn?(insn)
    @ruby_iseq[13].include?(insn)
  end

  def reset!
    @insns = @ruby_iseq[13].dup
  end

  def file
    @ruby_iseq[6]
  end

  def line
    @ruby_iseq[8]
  end

  def kind
    @ruby_iseq[9]
  end

  def shift_insn
    insns.shift
  end

  def name
    @ruby_iseq[5]
  end

  def lvar_names
    @ruby_iseq[10]
  end

  def args_info
    @ruby_iseq[11]
  end

  def pretty
    "#{kind} #{name} at #{file}:#{line}"
  end

  def setup_rescue_handlers!
    @rescue_handlers = @ruby_iseq[12]
      .select { |handler| handler[0] == :rescue }
      .map { |(_, iseq, begin_label, end_label, exit_label)| Handler.new(iseq, begin_label, end_label, exit_label) }
  end

  def setup_ensure_handlers!
    @ensure_handlers = @ruby_iseq[12]
      .select { |handler| handler[0] == :ensure }
      .map { |(_, iseq, begin_label, end_label, exit_label)| Handler.new(iseq, begin_label, end_label, exit_label) }
  end

  class Handler
    attr_reader :iseq
    attr_reader :begin_label, :end_label, :exit_label
    def initialize(iseq, begin_label, end_label, exit_label)
      @iseq = iseq
      @begin_label, @end_label, @exit_label = begin_label, end_label, exit_label
    end
  end
end
