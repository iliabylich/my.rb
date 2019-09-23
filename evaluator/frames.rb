require_relative './locals'

require_relative './frames/definition_scope'
require_relative './frames/backtrace_entry'

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

require_relative './frames/top_frame'
require_relative './frames/class_frame'
require_relative './frames/method_frame'

class FrameStack
  include Enumerable

  def initialize
    @stack = []
  end

  def each
    return to_enum(__method__) unless block_given?

    @stack.each { |item| yield item }
  end

  def enter_top(**args)
    @stack << TopFrame.new(**args)
    yield
  ensure
    @stack.pop
  end

  def enter_class(**args)
    @stack << ClassFrame.new(**args)
    yield
  ensure
    @stack.pop
  end

  def enter_method(**args)
    @stack << MethodFrame.new(**args)
    yield
  ensure
    @stack.pop
  end

  def top
    @stack.last
  end

  def size
    @stack.size
  end

  def to_backtrace
    [
      *@stack.map { |frame| BacktraceEntry.new(frame) },
      "... MRI backtrace...",
      *caller,
      "...Internal backtrace..."
    ]
  end
end
