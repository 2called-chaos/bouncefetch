# frozen_string_literal: true

module Bouncefetch
  # Logger Singleton
  MAIN_THREAD = ::Thread.main
  def MAIN_THREAD.app_logger
    MAIN_THREAD[:app_logger] ||= Banana::Logger.new
  end

  class Application
    RetryMailMatchSignal = Class.new(::RuntimeError)

    attr_reader :opts, :registry, :stats, :config, :rules, :skip

    include Helper
    include Dispatch
    include Imap
    include Setup

    def self.dispatch *a
      new(*a) do |app|
        app.parse_params
        app.logger
        begin
          app.dispatch
        rescue Interrupt
          app.abort("Interrupted", exit: 1)
        end
      end
    end

    def handle_mail bbmail
      begin
        case match = bbmail.match
          when nil   then bbmail.nocrosscheck!
          when false then bbmail.unmatched!
          else
            type, rule = match
            case mode = cfg("cause_mapping")[type.to_sym]
              when "leave"        then bbmail.ignore!(delete: false)
              when "ignore"       then bbmail.ignore!
              when "soft", "hard" then bbmail.handle!(mode, rule, ignore_missing_ref: rule.opts.key?(:ref) ? rule.opts[:ref] : false)
              when "soft?"        then bbmail.handle!(:soft, rule, ignore_missing_ref: true)
              when "hard?"        then bbmail.handle!(:hard, rule, ignore_missing_ref: true)
              else raise("no cause mapping for type `#{type}'")
            end
        end
      rescue RetryMailMatchSignal
        retry
      rescue StandardError => ex
        warn ex.message
        warn ex.backtrace.detect{|l| l.include?(ROOT.to_s) }
      end
    end


    # ==========
    # = Logger =
    # ==========
    [:log, :warn, :abort, :debug].each do |meth|
      define_method meth, ->(*args, **kw, &block) { Thread.main.app_logger.send(meth, *args, **kw, &block) }
    end

    def logger
      Thread.main.app_logger
    end

    # Shortcut for logger.colorize
    def c str, color = :yellow
      logger.colorize? ? logger.colorize(str, color) : str
    end

    def ask question
      logger.log_with_print(clear: false) do
        log c("#{question} ", :blue)
        $stdout.flush
        $stdin.gets.chomp
      end
    end
  end
end
