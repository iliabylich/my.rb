#! /usr/bin/env ruby

require 'pp'
require_relative '../cli'
require_relative '../vm'

class RubyRb
  def self.require(file)
    iseq = RubyVM::InstructionSequence.compile_file(file)
    $0 = file
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
      ['.rb', '.bundle'].each do |ext|
        filepath_with_ext = filepath.end_with?(ext) ? filepath : filepath + ext
        candidates = ['/', *$LOAD_PATH].map { |dir| File.join(dir, filepath_with_ext) }
        resolved = candidates.detect { |f| File.exist?(f) }

        if resolved
          if File.extname(resolved) == '.rb'
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
  end
end


cli = CLI.new

cli.run(
  eval: ->(code) { RubyRb.eval(code) },
  require: ->(file) { RubyRb.require(file) }
)
