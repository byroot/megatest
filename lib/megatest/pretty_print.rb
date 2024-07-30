# frozen_string_literal: true

# TODO: Consider inlining and modifying PP
require "pp"

# :stopdoc:

module Megatest
  class PrettyPrint
    def initialize(config)
      @config = config
    end

    using Compat::BindCall unless UnboundMethod.method_defined?(:bind_call)

    def pretty_print(object)
      case object
      when Exception
        [
          "Class: <#{pp(object.class)}>",
          "Message: <#{object.message.inspect}>",
          "---Backtrace---",
          *@config.backtrace.clean(object.backtrace),
          "---------------",
        ].join("\n")
      else
        begin
          PP.pp(object, "".dup).strip
        rescue NoMethodError
          # Ref: https://github.com/ruby/pp/pull/26
          Object.instance_method(:inspect).bind_call(object)
        end
      end
    end
    alias_method :pp, :pretty_print
  end
end
