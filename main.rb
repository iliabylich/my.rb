#! /usr/bin/env ruby

require 'pp'
require_relative './runner'
require_relative './evaluator'

class RubyRb
  def self.require(file)
    iseq = RubyVM::InstructionSequence.compile_file(file)
    run_instruction(iseq)
  end

  def self.eval(code)
    iseq = RubyVM::InstructionSequence.compile(code)
    run_instruction(iseq)
  end

  def self.run_instruction(iseq)
    Evaluator.new.execute(iseq.to_a)
  end
end

runner = Runner.new
runner.run(
  eval: ->(code) { RubyRb.eval(code) },
  require: ->(file) { RubyRb.require(file) }
)
