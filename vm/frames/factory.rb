class FrameClass
  COMMON_FRAME_ATTRIBUTES = %i[
    _self
    nesting
    locals
    file
    line
    name
  ].freeze

  def self.new(*arguments, &block)
    Struct.new(
      *COMMON_FRAME_ATTRIBUTES,
      *arguments,
      keyword_init: true
    ) do
      attr_reader :iseq
      attr_reader :stack

      attr_reader :labels_to_skip
      attr_reader :in_module_function_section

      attr_accessor :current_error

      attr_accessor :returning

      attr_reader :svars

      attr_reader :enabled_rescue_handlers
      attr_reader :enabled_ensure_handlers

      def pretty_name
        raise VM::InternalError, "#{self.class}#pretty_name is missing"
      end

      def can_return?;    false; end
      def can_do_next?;   false; end
      def can_yield?;     false; end
      def can_do_break?;  false; end
      def eval?;          false; end

      def prepare; end

      class_eval(&block)

      def self.new(iseq:, **attributes)
        instance = allocate

        instance.instance_eval {
          @iseq = iseq
          @stack = Stack.new
          @labels_to_skip = []
          @in_module_function_section = false
          @svars = {}
          @enabled_rescue_handlers = []
          @enabled_ensure_handlers = []
        }

        instance.file = iseq.file
        instance.line = iseq.line
        instance.name = iseq.name
        instance.locals = Locals.new(iseq.lvar_names)

        instance.returning = :UNDEFINED

        instance.send(:initialize, **attributes)

        instance
      end

      def header
        "#{self.class} frame (#{pretty_name} in #{file}:#{line})"
      end

      def open_module_function_section!
        @in_module_function_section = true
      end

      def has_returning?
        @returning != :UNDEFINED
      end

      def exit!(value)
        VM.instance.__log { "... scheduling force [:leave] (on #{self.name} with #{value.inspect})" }
        @returning = value

        iseq.insns.clear
        iseq.insns.push([:leave])

        stack.clear
        stack.push(value)
        stack.disable_push!
      end
    end
  end
end
