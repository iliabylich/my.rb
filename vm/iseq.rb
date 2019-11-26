class ISeq
  attr_reader :insns

  def initialize(ruby_iseq)
    @ruby_iseq = ruby_iseq
    @insns = ruby_iseq[13].dup
  end

  def handlers
    @ruby_iseq[12]
  end

  def handler(name)
    _name, iseq = handlers.detect { |handler| handler[0] == name }
    iseq
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

  def arg_names
    @ruby_iseq[10]
  end

  def args_info
    @ruby_iseq[11]
  end
end
