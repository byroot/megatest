# frozen_string_literal: true

if __FILE__ == $PROGRAM_NAME
  require "megatest"
  read = IO.for_fd(Integer(ARGV.fetch(0)))
  write = IO.for_fd(Integer(ARGV.fetch(1)))
  exit!(Megatest::Subprocess.new(read, write).run(ARGV.fetch(2)))
end
