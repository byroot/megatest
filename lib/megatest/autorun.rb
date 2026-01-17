# frozen_string_literal: true

require "megatest"

unless Megatest.running
  root = File.expand_path("../../", __dir__)
  rubyopt = "#{ENV.fetch("RUBYOPT", nil)} -I#{root}/lib"
  exec({ "RUBYOPT" => rubyopt }, "#{root}/exe/megatest", $PROGRAM_NAME, *ARGV)
end
