class VM
  class InternalError < ::Exception
    def initialize(*)
      super
      set_backtrace(VM.instance.backtrace)
    end
  end

  class LongJumpError  < InternalError
    attr_reader :value

    def initialize(value)
      @value = value
    end

    def do_jump!
      raise InternalError, 'Not implemented'
    end

    def message
      "#{self.class}(#{@value.inspect})"
    end
  end

  class ReturnError < LongJumpError
    def do_jump!
      frame = VM.instance.current_frame

      if frame.can_return?
        # swallow
        frame.returning = self.value
      else
        VM.instance.pop_frame(reason: "longjmp (return) #{self}")
        raise self
      end
    end
  end

  class NextError < LongJumpError
    def do_jump!
      frame = VM.instance.current_frame

      if frame.can_do_next?
        # swallow
        frame.returning = self.value
      else
        VM.instance.pop_frame(reason: "longjmp (next) #{self}")
        raise self
      end
    end
  end

  class BreakError < LongJumpError
    def do_jump!
      frame = VM.instance.current_frame

      if frame.can_do_break?
        if frame.is_lambda
          frame.returning = self.value
        else
          VM.instance.pop_frame(reason: "propagating block return #{self}")
          raise ReturnError, self.value
        end
      else
        VM.instance.pop_frame(reason: "longjmp (break) #{self}")
        raise self
      end
    end
  end
end
