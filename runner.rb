require 'optparse'

class Runner
  def parse_argv
    options = { require: [], load_path: [], eval: nil }
    OptionParser.new do |opts|
      opts.banner = 'Usage: run.rb [options]'

      opts.on('-I=PATH', 'Append load path') do |path|
        options[:load_path] << path
      end

      opts.on('-rFILE', '--require=FILE', 'Require file') do |file|
        options[:require] << file
      end

      opts.on('-e=CODE') do |code|
        options[:eval] = code
      end

      opts.on('--print-missing-insns', 'Print missing insns') do
        options[:print_missing_insns] = true
      end

      opts.on('-h', '--help', 'Prints this help') do
        puts opts
        exit
      end
    end.parse!

    options[:files_to_run] = ARGV

    if options[:print_missing_insns]
      all = RubyVM::INSTRUCTION_NAMES.map { |insn| :"execute_#{insn}" }.grep_v(/execute_trace_/)
      existing = Evaluator.instance_methods
      existing &= all
      missing = all - existing
      puts "+#{existing.length} / -#{missing.length} / total: #{all.length}"
      puts missing
      exit(0)
    end

    if options[:eval] && options[:files_to_run].any?
      raise "-e and [file].rb are mutually exclusive"
    end

    if options[:eval].nil? && options[:files_to_run].empty?
      raise "at least one of -e or [file].rb must be given"
    end

    options
  end

  def run(eval:, require:)
    options = parse_argv

    puts "Running with #{options.inspect}"

    options[:load_path].each { |path| $LOAD_PATH << path }
    options[:require].each { |path| require[path] }
    if (code = options[:eval])
      eval[code]
    end
    options[:files_to_run].each { |path| require[path] }
  end
end
