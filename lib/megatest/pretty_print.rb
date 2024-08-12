# frozen_string_literal: true

require "prettyprint"

# :stopdoc:

module Megatest
  class PrettyPrint
    # This class is largely a copy of the `pp` gem
    # but rewritten to not rely on monkey patches
    # and with some small rendering modifications
    # notably around multiline strings.
    class Printer < ::PrettyPrint
      class << self
        def pp(obj, out = +"", width = 79)
          q = new(out, width)
          q.guard_inspect_key { q.pp obj }
          q.flush
          out
        end
      end

      # Yields to a block
      # and preserves the previous set of objects being printed.
      def guard_inspect_key
        @recursive_key = {}.compare_by_identity

        save = @recursive_key

        begin
          @recursive_key = {}.compare_by_identity
          yield
        ensure
          @recursive_key = save
        end
      end

      # Check whether the object_id +id+ is in the current buffer of objects
      # to be pretty printed. Used to break cycles in chains of objects to be
      # pretty printed.
      def check_inspect_key(id)
        @recursive_key&.include?(id)
      end

      # Adds the object_id +id+ to the set of objects being pretty printed, so
      # as to not repeat objects.
      def push_inspect_key(id)
        @recursive_key[id] = true
      end

      # Removes an object from the set of objects being pretty printed.
      def pop_inspect_key(id)
        @recursive_key.delete id
      end

      # Adds +obj+ to the pretty printing buffer
      # using Object#pretty_print or Object#pretty_print_cycle.
      #
      # Object#pretty_print_cycle is used when +obj+ is already
      # printed, a.k.a the object reference chain has a cycle.
      def pp(obj)
        # If obj is a Delegator then use the object being delegated to for cycle
        # detection
        obj = obj.__getobj__ if defined?(::Delegator) && ::Delegator === obj

        if check_inspect_key(obj)
          group { pretty_print_cycle(obj) }
          return
        end

        begin
          push_inspect_key(obj)
          group { pretty_print(obj) }
        ensure
          pop_inspect_key(obj)
        end
      end

      # A convenience method which is same as follows:
      #
      #   group(1, '#<' + obj.class.name, '>') { ... }
      def object_group(obj, &block)
        group(1, "#<#{obj.class.name}>", &block)
      end

      using Compat::BindCall unless UnboundMethod.method_defined?(:bind_call)

      # A convenience method, like object_group, but also reformats the Object's
      # object_id.
      def object_address_group(obj, &block)
        str = Kernel.instance_method(:to_s).bind_call(obj)
        str.chomp!(">")
        group(1, str, ">", &block)
      end

      # A convenience method which is same as follows:
      #
      #   text ','
      #   breakable
      def comma_breakable
        text ","
        breakable
      end

      # Adds a separated list.
      # The list is separated by comma with breakable space, by default.
      #
      # #seplist iterates the +list+ using +iter_method+.
      # It yields each object to the block given for #seplist.
      # The procedure +separator_proc+ is called between each yields.
      #
      # If the iteration is zero times, +separator_proc+ is not called at all.
      #
      # If +separator_proc+ is nil or not given,
      # +lambda { comma_breakable }+ is used.
      # If +iter_method+ is not given, :each is used.
      #
      # For example, following 3 code fragments has similar effect.
      #
      #   q.seplist([1,2,3]) {|v| xxx v }
      #
      #   q.seplist([1,2,3], lambda { q.comma_breakable }, :each) {|v| xxx v }
      #
      #   xxx 1
      #   q.comma_breakable
      #   xxx 2
      #   q.comma_breakable
      #   xxx 3
      def seplist(list, sep = nil, iter_method = :each)
        sep ||= -> { comma_breakable }
        first = true
        list.__send__(iter_method) do |*v|
          if first
            first = false
          else
            sep.call
          end
          yield(*v)
        end
      end

      # A present standard failsafe for pretty printing any given Object
      def pp_object(obj)
        object_address_group(obj) do
          seplist(pretty_print_instance_variables(obj), -> { text "," }) do |v|
            breakable
            v = v.to_s if Symbol === v
            text v
            text "="
            group(1) do
              breakable ""
              pp(obj.instance_eval(v))
            end
          end
        end
      end

      INSTANCE_VARIABLES = Object.instance_method(:instance_variables)
      def pretty_print_instance_variables(obj)
        INSTANCE_VARIABLES.bind_call(obj).sort
      end

      # A pretty print for a Hash
      def pp_hash(obj)
        group(1, "{", "}") do
          seplist(obj, nil, :each_pair) do |k, v|
            group do
              pp k
              text "=>"
              group(1) do
                breakable ""
                pp v
              end
            end
          end
        end
      end

      using Compat::ByteRIndex unless String.method_defined?(:byterindex)

      CLASS = Kernel.instance_method(:class)

      def pretty_print(obj)
        case obj
        when String
          if obj.size > 30 && obj.byterindex("\n", -1)
            text obj.inspect.gsub('\n', "\\n\n").sub(/\\n\n"\z/, '\n"')
          else
            text obj.inspect
          end
        when Array
          group(1, "[", "]") do
            seplist(obj) do |v|
              pp v
            end
          end
        when Hash
          pp_hash(obj)
        when Range
          pp obj.begin
          breakable ""
          text(obj.exclude_end? ? "..." : "..")
          breakable ""
          pp obj.end if obj.end
        when MatchData
          nc = []
          obj.regexp.named_captures.each do |name, indexes|
            indexes.each { |i| nc[i] = name }
          end

          object_group(obj) do
            breakable
            seplist(0...obj.size, -> { breakable }) do |i|
              if i != 0
                if nc[i]
                  text nc[i]
                else
                  pp i
                end
                text ":"
                pp obj[i]
              end
              pp obj[i]
            end
          end
        when Regexp, Symbol, Numeric, Module, true, false, nil
          text(obj.inspect)
        when Struct
          group(1, format("#<struct %s", CLASS.bind_call(obj)), ">") do
            seplist(Struct.instance_method(:members).bind_call(obj), -> { text "," }) do |member|
              breakable
              text member.to_s
              text "="
              group(1) do
                breakable ""
                pp obj[member]
              end
            end
          end
        else
          if ENV.equal?(obj)
            pp_hash(ENV.sort.to_h)
          elsif special_inspect?(obj)
            text(obj.inspect)
          else
            pp_object(obj)
          end
        end
      end

      def pretty_print_cycle(obj)
        case obj
        when Array
          text(obj.empty? ? "[]" : "[...]")
        when Hash
          text(obj.empty? ? "{}" : "{...}")
        when Struct
          text format("#<struct %s:...>", CLASS.bind_call(obj))
        when Numeric, Symbol, FalseClass, TrueClass, NilClass, Module
          text obj.inspect
        else
          object_address_group(obj) do
            breakable
            text "..."
          end
        end
      end

      METHOD = Object.instance_method(:method)
      def special_inspect?(obj)
        METHOD.bind_call(obj, :inspect).owner != Kernel
      rescue NoMethodError
        false
      end

      OBJECT_INSPECT = Object.instance_method(:inspect)

      def inspect_object(obj)
        obj.inspect
      rescue NoMethodError # Basic Object etc.
        OBJECT_INSPECT.bind_call(obj)
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
        Printer.pp(object, out)
        out.strip
      end
    end
    alias_method :pp, :pretty_print
  end
end
