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
require 'irb'
require 'irb/completion'
require 'readline'

module Kernel
  alias original_require require

  def require(filepath)
    ['.rb', '.bundle'].each do |ext|
      filepath_with_ext = filepath.end_with?(ext) ? filepath : filepath + ext
      candidates = ['/', *$LOAD_PATH].map { |dir| File.join(dir, filepath_with_ext) }
      resolved = candidates.detect { |f| File.exist?(f) }

      if resolved
        if $LOADED_FEATURES.include?(resolved)
          puts "skipping #{resolved}"
          return false # emulate original `require`
        elsif File.extname(resolved) == '.rb'
          puts "EVALING #{resolved}"
          RubyRb.require(resolved)
          return true
        else
          # .bundle or .so, we have to load it via ruby
        end
      end
    end

    puts "Unable to do `require '#{filepath}'"
    before = $LOADED_FEATURES.dup
    result = original_require(filepath)
    diff = $LOADED_FEATURES - before
    puts "Success, diff is #{diff.inspect}"
    result
  end
end

runner = Runner.new
runner.run(
  eval: ->(code) { RubyRb.eval(code) },
  require: ->(file) { RubyRb.require(file) }
)
