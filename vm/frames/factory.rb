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
      private :_iseq

      attr_reader :labels_to_skip
      attr_reader :in_module_function_section

      def pretty_name
        raise NotImplementedError, "#{self.class}#pretty_name is missing"
      end

      class_eval(&block)

      def self.new(iseq:, **attributes)
        instance = allocate

        instance.instance_eval {
          @_iseq = iseq
          @labels_to_skip = []
          @in_module_function_section = false
        }

        instance.file = iseq.file
        instance.line = nil
        instance.name = iseq.name

        instance.send(:initialize, **attributes)

        instance
      end

      def header
        "#{self.class} frame (#{pretty_name} in #{file}:#{line})"
      end

      def open_module_function_section!
        @in_module_function_section = true
      end
    end
  end
end
