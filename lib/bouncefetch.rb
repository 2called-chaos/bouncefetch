require "pathname"
require "optparse"
require "securerandom"
require "ostruct"
require "net/imap"
require "mail"
require "fileutils"
require "date"
require "csv"
# require "digest/sha1"
begin ; require "pry" ; rescue LoadError ; end

module Bouncefetch
  ROOT = Pathname.new(File.expand_path("../..", __FILE__))
  BASH_ENABLED = "#{ENV["SHELL"]}".downcase["bash"]
  $:.unshift "#{ROOT}/lib"

  def self.configure *args, &block
    Thread.main[:app_config].setup(*args, &block)
  end

  def self.rules *args, &block
    Thread.main[:app_rules].setup(*args, &block)
  end
end

require "active_support/core_ext/object/blank"
require "active_support/core_ext/object/try"
require "banana/logger"

require "bouncefetch/version"
require "bouncefetch/rule"
require "bouncefetch/bbmail"
require "bouncefetch/application/setup"
require "bouncefetch/application/configuration"
require "bouncefetch/application/helper"
require "bouncefetch/application/rules"
require "bouncefetch/application/imap"
require "bouncefetch/application/statistics"
require "bouncefetch/application/registry"
require "bouncefetch/application/dispatch"
require "bouncefetch/application"


if ARGV.shift == "dispatch"
  begin
    Bouncefetch::Application.dispatch(ENV, ARGV)
  rescue Interrupt
    puts("\n\nInterrupted")
    exit 1
  end
else
  puts("\n\nInvalid call")
  exit 1
end
