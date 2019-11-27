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
      attr_reader :_iseq

      attr_reader :labels_to_skip
      attr_reader :in_module_function_section

      attr_accessor :current_error

      attr_accessor :returning
      attr_accessor :exiting

      def pretty_name
        raise NotImplementedError, "#{self.class}#pretty_name is missing"
      end

      def can_return?;  false; end
      def can_do_next?; false; end

      def prepare; end

      class_eval(&block)

      def self.new(iseq:, **attributes)
        instance = allocate

        instance.instance_eval {
          @_iseq = iseq
          @labels_to_skip = []
          @in_module_function_section = false
        }

        instance.file = iseq.file
        instance.line = iseq.line
        instance.name = iseq.name

        instance.returning = :UNDEFINED
        instance.exiting   = false

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

      def exit!
        _iseq.insns.clear
        _iseq.insns.push([:leave])
        @exiting = true
      end

      def exiting?
        @exiting
      end
    end
  end
end
