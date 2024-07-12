# frozen_string_literal: true

# TODO: Consider inlining and modifying PP
require "pp"

module Megatest
  class PrettyPrint
    def initialize(config)
      @config = config
    end

    using Compat::BindCall unless UnboundMethod.method_defined?(:bind_call)

    def pretty_print(object)
      PP.pp(object, "".dup).strip
    rescue NoMethodError
      # Ref: https://github.com/ruby/pp/pull/26
      Object.instance_method(:inspect).bind_call(object)
    end
  end
end
