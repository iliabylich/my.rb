require 'optparse'

class CLI
  def parse_argv
    options = {
      require: [],
      load_path: [],
      eval: nil,
      pre: nil,
      debug: false,
      debug_focus_on: nil,
      debug_show_stack: false,
      debug_print_rest_on_error: false
    }

    OptionParser.new do |opts|
      opts.banner = 'Usage: run.rb [options]'

      opts.on('--pre=CODE') do |code|
        options[:pre] = code
      end

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

      opts.on('--debug', 'Run in debug mode') do
        options[:debug] = true
      end

      opts.on('--debug-focus-on=FRAME', 'Focus on some specific frame') do |debug_focus_on|
        options[:debug_focus_on] = debug_focus_on
      end

      opts.on('--debug-show-stack') do
        options[:debug_show_stack] = true
      end

      opts.on('--debug-print-rest-on-error') do
        options[:debug_print_rest_on_error] = true
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

    if options[:debug]
      $debug = $stdout
    else
      $debug = StringIO.new
    end

    VM.instance.debug_focus_on = options[:debug_focus_on]
    VM.instance.debug_show_stack = options[:debug_show_stack]
    VM.instance.debug_print_rest_on_error = options[:debug_print_rest_on_error]

    options[:load_path].each { |path| $LOAD_PATH << path }
    if (pre = options[:pre])
      eval(pre)
    end
    options[:require].each { |path| require[path] }
    if (code = options[:eval])
      eval[code]
    end
    options[:files_to_run].each { |path| $0 = path; require[path] }
  end
end
