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

      def pretty_name
        raise NotImplementedError, "#{self.class}#pretty_name is missing"
      end

      class_eval(&block)

      def self.new(iseq:, **attributes)
        instance = allocate

        instance.instance_eval {
          @_iseq = iseq
          @labels_to_skip = []
        }

        instance.file = iseq[6]
        instance.line = nil
        instance.name = iseq[5]

        instance.send(:initialize, **attributes)

        instance
      end
    end
  end
end
