# frozen_string_literal: true

module Dru
  module Stackable
    def push data
      stack.push data
    end

    def pop
      stack.pop
    end

    def shift
      return stack.shift if stack.size > 0
      nil
    end

    # Peek the top of the stack
    def peek
      return stack[-1] if stack.size > 0
      nil
    end

    def peek_first
      return stack[0] if stack.size > 0
      nil
    end

    def inspect
      stack.inspect
    end

    def clear
      stack.clear
    end

    def size
      stack.size
    end

    # Accessed through push and pop
    def stack
      @stack ||= []
    end
    private :stack
  end
end
