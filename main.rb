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

# patch `require`, it's not a "kernel patch"
module KernelPatch
  def require(filepath)
    filepath_with_ext = filepath.end_with?('.rb') ? filepath : filepath + '.rb'
    candidates = $LOAD_PATH.map { |dir| File.join(dir, filepath_with_ext) }
    resolved = candidates.detect { |f| File.exist?(f) }

    if resolved
      if $LOADED_FEATURES.include?(resolved)
        false # emulate original `require`
      else
        RubyRb.require(resolved)
      end
    else
      puts "Unable to do `require '#{filepath}'"
      before = $LOADED_FEATURES.dup
      result = super
      diff = $LOADED_FEATURES - before
      puts "Success, diff is #{diff.inspect}"
      result
    end
  end
end
Kernel.prepend(KernelPatch)

runner = Runner.new
runner.run(
  eval: ->(code) { RubyRb.eval(code) },
  require: ->(file) { RubyRb.require(file) }
)
