# frozen_string_literal: true

module Megatest
  module Compat
    unless Enumerable.method_defined?(:filter_map)
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

    unless Symbol.method_defined?(:start_with?)
      module StartWith
        refine Symbol do
          def start_with?(*args)
            to_s.start_with?(*args)
          end
        end
      end
    end

    unless Symbol.method_defined?(:name)
      module Name
        refine Symbol do
          alias_method :name, :to_s
        end
      end
    end

    unless String.method_defined?(:byterindex)
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

    unless UnboundMethod.method_defined?(:bind_call)
      module BindCall
        refine UnboundMethod do
          def bind_call(receiver, *args, &block)
            bind(receiver).call(*args, &block)
          end
        end
      end
    end
  end
end
