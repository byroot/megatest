# frozen_string_literal: true

module Megatest
  class Subprocess
    class << self
      def spawn(read, write, action)
        Process.spawn(
          RbConfig.ruby,
          File.expand_path("../subprocess/main.rb", __FILE__),
          read.fileno.to_s,
          write.fileno.to_s,
          action,
          read.fileno => read,
          write.fileno => write,
        )
      end
    end

    def initialize(read, write)
      @read = read
      @write = write
    end

    def run(action)
      case action
      when "run_test"
        config = Marshal.load(@read)
        Megatest.init(config)

        test_path = Marshal.load(@read)
        test_cases = Megatest.load_tests(config, [test_path])
        test_id = Marshal.load(@read)
        @read.close
        test_case = test_cases.find { |t| t.id == test_id }
        unless test_case
          exit!(1) # TODO: error
        end

        result = Runner.new(config).run(test_case)
        Marshal.dump(result, @write)
        @write.close
      else
        exit!(1)
      end
      exit!(0)
    end
  end
end
