# frozen_string_literal: true

# :stopdoc:

module Megatest
  module Compat
    unless Enumerable.method_defined?(:filter_map) # RUBY_VERSION >= "2.7"
      module FilterMap
        refine Enumerable do
          def filter_map(&block)
            result = map(&block)
            result.compact!
            result
          end
        end
      end
    end

    unless Symbol.method_defined?(:start_with?) # RUBY_VERSION >= "2.7"
      module StartWith
        refine Symbol do
          def start_with?(*args)
            to_s.start_with?(*args)
          end
        end
      end
    end

    unless UnboundMethod.method_defined?(:bind_call) # RUBY_VERSION >= "2.7"
      module BindCall
        refine UnboundMethod do
          def bind_call(receiver, *args, &block)
            bind(receiver).call(*args, &block)
          end
        end
      end
    end

    unless Enumerable.method_defined?(:tally) # RUBY_VERSION >= "2.7"
      module Tally
        refine Enumerable do
          def tally(hash = {})
            each do |element|
              hash[element] = (hash[element] || 0) + 1
            end
            hash
          end
        end
      end
    end

    unless Symbol.method_defined?(:name) # RUBY_VERSION >= "3.0"
      module Name
        refine Symbol do
          alias_method :name, :to_s
        end
      end
    end

    unless String.method_defined?(:byterindex) # RUBY_VERSION >= "3.2"
      module ByteRIndex
        refine String do
          def byterindex(matcher, offset = -1)
            if encoding == Encoding::BINARY
              rindex(matcher, offset)
            else
              b.rindex(matcher, offset)
            end
          end
        end
      end
    end
  end
end
