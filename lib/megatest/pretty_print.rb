# frozen_string_literal: true

require "pp"

# :stopdoc:

module Megatest
  class PrettyPrint
    class Printer < PP
      def pp(obj)
        # If obj is a Delegator then use the object being delegated to for cycle
        # detection
        obj = obj.__getobj__ if defined?(::Delegator) && ::Delegator === obj

        if check_inspect_key(obj)
          group { obj.pretty_print_cycle self }
          return
        end

        begin
          push_inspect_key(obj)
          group { pretty_print_obj(obj) }
        ensure
          pop_inspect_key(obj) unless PP.sharing_detection
        end
      end

      using Compat::ByteRIndex unless String.method_defined?(:byterindex)

      def pretty_print_obj(obj)
        case obj
        when String
          if obj.size > 30 && obj.byterindex("\n", -1)
            text obj.inspect.gsub('\n', "\\n\n").sub(/\\n\n"\z/, '\n"')
          else
            text obj.inspect
          end
        else
          begin
            obj.pretty_print self
          rescue NoMethodError
            # Ref: https://github.com/ruby/pp/pull/26
            text Object.instance_method(:inspect).bind_call(obj)
          end
        end
      end
    end

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
        out = "".dup
        printer = Printer.new(out)
        printer.pp(object)
        printer.flush
        out
      end
    end
    alias_method :pp, :pretty_print
  end
end
