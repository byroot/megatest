# frozen_string_literal: true

module Megatest
  class Assertion < Exception
  end

  module Assertions
    def assert(result, message: nil)
      @__mega_state.assertions += 1
      return if result

      flunk(message)
    end

    def flunk(postional_message = nil, message: postional_message)
      message ||= "Failed"
      message = message.call if message.respond_to?(:call)
      ::Kernel.raise(::Megatest::Assertion, String(message))
    end
  end
end
