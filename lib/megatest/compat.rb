# frozen_string_literal: true

module Megatest
  module Compat
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
