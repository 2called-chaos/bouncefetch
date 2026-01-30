# frozen_string_literal: true

# core
require "benchmark"
require "pathname"
require "optparse"
require "base64"
require "fileutils"

require "cgi"
require "date"
require "mail"
require "net/imap"

# candidate export
require "json"
require "csv"
require "net/http"

begin ; require "pry" ; rescue LoadError ; end

module Bouncefetch
  ROOT = Pathname.new(File.expand_path("..", __dir__))
  BASH_ENABLED = ENV.fetch("SHELL", nil)&.downcase&.include?("bash")

  def self.configure *args, &block
    Thread.main[:app_config].setup(*args, &block)
  end

  def self.rules *args, &block
    Thread.main[:app_rules].setup(*args, &block)
  end
end

require_relative "active_support/core_ext/object/blank"
require_relative "active_support/core_ext/string/filter"
require_relative "banana/logger"

require_relative "bouncefetch/version"
require_relative "bouncefetch/rule"
require_relative "bouncefetch/bbmail"
require_relative "bouncefetch/application/setup"
require_relative "bouncefetch/application/configuration"
require_relative "bouncefetch/application/helper"
require_relative "bouncefetch/application/rules"
require_relative "bouncefetch/application/imap"
require_relative "bouncefetch/application/statistics"
require_relative "bouncefetch/application/registry"
require_relative "bouncefetch/application/dispatch"
require_relative "bouncefetch/application"


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
