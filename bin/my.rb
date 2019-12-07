#! /usr/bin/env ruby

require 'pp'
require_relative '../cli'
require_relative '../vm'

class RubyRb
  REAL_EVAL = Kernel.instance_method(:eval)
  REAL_INSTANCE_EVAL = BasicObject.instance_method(:instance_eval)
  REAL_MODULE_EVAL = Module.instance_method(:module_eval)
  REAL_CLASS_EVAL = Module.instance_method(:class_eval)
  REAL_KERNEL_LAMBDA = Kernel.instance_method(:lambda)

  def self.require(file)
    iseq = RubyVM::InstructionSequence.compile_file(file)
    run_instruction(iseq)
  end

  def self.eval(code)
    iseq = RubyVM::InstructionSequence.compile(code)
    run_instruction(iseq)
  end

  def self.run_instruction(iseq)
    VM.instance.execute(iseq.to_a)
  end
end
require 'irb'
require 'irb/completion'
require 'readline'
require '/Users/ilya/.rvm/scripts/irbrc.rb'

[Kernel, Kernel.singleton_class].each do |mod|
  mod.module_eval do
    alias original_require require

    def require(filepath)
      ['.rb', '.bundle'].each do |ext|
        filepath_with_ext = filepath.end_with?(ext) ? filepath : filepath + ext
        candidates = ['/', *$LOAD_PATH].map { |dir| File.join(dir, filepath_with_ext) }
        resolved = candidates.detect { |f| File.exist?(f) }

        if resolved
          if $LOADED_FEATURES.include?(resolved)
            $debug.puts "skipping #{resolved}"
            return false # emulate original `require`
          elsif File.extname(resolved) == '.rb'
            $debug.puts "require #{resolved}"
            $LOADED_FEATURES << resolved
            RubyRb.require(resolved)
            return true
          else
            # .bundle or .so, we have to load it via ruby
          end
        end
      end

      $debug.puts "Unable to do `require '#{filepath}'"
      before = $LOADED_FEATURES.dup
      result = original_require(filepath)
      diff = $LOADED_FEATURES - before
      $debug.puts "Success, diff is #{diff.inspect}"
      result
    end

    alias original_load load

    def load(filepath)
      ['.rb', '.bundle', ''].each do |ext|
        filepath_with_ext = filepath.end_with?(ext) ? filepath : filepath + ext
        candidates = ['/', *$LOAD_PATH].map { |dir| File.join(dir, filepath_with_ext) }
        resolved = candidates.detect { |f| File.exist?(f) }

        if resolved
          if ['.rb', '.mspec'].include?(File.extname(resolved))
            $debug.puts "load #{resolved}"
            RubyRb.require(resolved)
            $LOADED_FEATURES << resolved unless $LOADED_FEATURES.include?(resolved)
            return true
          else
            # .bundle or .so, we have to load it via ruby
          end
        end
      end

      $debug.puts "Unable to do `load '#{filepath}'"
      before = $LOADED_FEATURES.dup
      result = original_require(filepath)
      diff = $LOADED_FEATURES - before
      $debug.puts "Success, diff is #{diff.inspect}"
      result
    end

    alias original_require_relative require_relative

    def require_relative(filepath)
      original_filepath = filepath
      filepath = File.join('..', filepath)
      running = File.expand_path(VM.instance.current_frame.file)
      resolved = File.expand_path(filepath, running)

      resolved = resolved + '.rb' unless resolved.end_with?('.rb')

      if resolved && File.exist?(resolved)
        if $LOADED_FEATURES.include?(resolved)
          $debug.puts "skipping #{resolved}"
          return false # emulate original `require_relative`
        else
          $debug.puts "require_relative #{resolved}"
          $LOADED_FEATURES << resolved
          RubyRb.require(resolved)
          return true
        end
      end

      $debug.puts "Unable to do `require_relative '#{original_filepath}'"
      before = $LOADED_FEATURES.dup
      result = original_require_relative(original_filepath)
      diff = $LOADED_FEATURES - before
      $debug.puts "Success, diff is #{diff.inspect}"
      result
    rescue LoadError
      binding.irb
    end

    def eval(code)
      iseq = RubyVM::InstructionSequence.compile(code).to_a
      iseq[9] = :eval
      VM.instance.execute(iseq, _self: self)
    end
  end
end

class BasicObject
  def instance_eval(code = nil, &block)
    if code
      iseq = ::RubyVM::InstructionSequence.compile(code).to_a
      iseq[9] = :eval
      ::VM.instance.execute(iseq, _self: self)
    else
      ::RubyRb::REAL_INSTANCE_EVAL.bind(self).call(&block)
    end
  end
end

class Module
  def module_eval(code = nil, &block)
    if code
      iseq = ::RubyVM::InstructionSequence.compile(code).to_a
      iseq[9] = :eval
      ::VM.instance.execute(iseq, _self: self)
    else
      ::RubyRb::REAL_MODULE_EVAL.bind(self).call(&block)
    end
  end

  def class_eval(code = nil, &block)
    if code
      iseq = ::RubyVM::InstructionSequence.compile(code).to_a
      iseq[9] = :eval
      ::VM.instance.execute(iseq, _self: self)
    else
      ::RubyRb::REAL_CLASS_EVAL.bind(self).call(&block)
    end
  end
end

cli = CLI.new

if ENV['DISABLE_BREAKPOINTS']
  class Binding
    def irb
      e = NotImplementedError.new('binding.irb')
      e.set_backtrace(caller(5))
      raise e
    end
  end
end

cli.run(
  eval: ->(code) { RubyRb.eval(code) },
  require: ->(file) { RubyRb.require(file) }
)
