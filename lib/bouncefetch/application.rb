module Bouncefetch
  # Logger Singleton
  MAIN_THREAD = ::Thread.main
  def MAIN_THREAD.app_logger
    MAIN_THREAD[:app_logger] ||= Banana::Logger.new
  end

  class Application
    attr_reader :opts, :registry, :stats, :config, :rules
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
          app.abort("Interrupted", 1)
        end
      end
    end

    def handle_mail bbmail
      begin
        case match = bbmail.match?
          when nil   then bbmail.nocrosscheck!
          when false then bbmail.unmatched!
          else
            type, rule = match
            case mode = cfg("cause_mapping")[type.to_sym]
              when "leave"        then bbmail.ignore!(false)
              when "ignore"       then bbmail.ignore!
              when "soft", "hard" then bbmail.handle!(mode, rule)
              else raise("no cause mapping for type `#{type}'")
            end
        end
      rescue
        warn $!.message
        warn $!.backtrace.detect{|l| l.include?(ROOT) }
      end
    end


    # ==========
    # = Logger =
    # ==========
    [:log, :warn, :abort, :debug].each do |meth|
      define_method meth, ->(*a, &b) { Thread.main.app_logger.send(meth, *a, &b) }
    end

    def logger
      Thread.main.app_logger
    end

    # Shortcut for logger.colorize
    def c str, color = :yellow
      logger.colorize? ? logger.colorize(str, color) : str
    end

    def ask question
      logger.log_with_print(false) do
        log c("#{question} ", :blue)
        STDOUT.flush
        STDIN.gets.chomp
      end
    end
  end
end
