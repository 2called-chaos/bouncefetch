module Bouncefetch
  # Logger Singleton
  MAIN_THREAD = ::Thread.main
  def MAIN_THREAD.app_logger
    MAIN_THREAD[:app_logger] ||= Banana::Logger.new
  end

  class Application
    attr_reader :opts, :registry, :stats, :config, :rules
    include Dispatch
    include Imap

    # =========
    # = Setup =
    # =========
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

    def initialize env, argv
      @env, @argv = env, argv
      @opts = {
        dispatch: :index,
        check_for_updates: true,
        simulate: false,
        throttle_detect: true,
      }

      # statistics
      @stats = Statistics.new
      @stats.add(:mails_checked)          {|v, n| [c(v, :blue),  c(n)].join(" ") }
      @stats.add(:deleted_mails)          {|v, n| [c(v, :red),   c(n)].join(" ") }
      @stats.add(:handled_soft_bounces)   {|v, n| [c(v, :green), c(n)].join(" ") }
      @stats.add(:handled_hard_bounces)   {|v, n| [c(v, :green), c(n)].join(" ") }
      @stats.add(:ignored_mails)          {|v, n| [c(v, :blue),  c(n)].join(" ") }
      @stats.add(:unidentifyable_bounces) {|v, n| [c(v, :red),   c(n)].join(" ") }
      @stats.add(:no_crosscheck_matched)  {|v, n| [c(v, :red),   c(n)].join(" ") }
      @stats.add(:unhandled_mails)        {|v, n| [c(v, :red),   c(n)].join(" ") }

      yield(self)
    end

    def parse_params
      @optparse = OptionParser.new do |opts|
        opts.banner = "Usage: bouncefetch [options]"

        opts.on("-c", "--candidates", "list unsubscribe candidates") { @opts[:dispatch] = :list_candidates }
        opts.on("-s", "--statistics", "show statistics about the registry and candidates") { @opts[:dispatch] = :statistics }
        opts.on("-e", "--export FILE", String, "export unsubscribe candidates to file and remove them from the registry") {|f| @opts[:dispatch] = :export ; @opts[:remote] = f }
        opts.on("-r", "--remote RESOURCE", String, "post unsubscribe candidates to URL and remove them from the registry") {|f| @opts[:dispatch] = :export_remote ; @opts[:remote] = f }
        opts.on("-d", "--dryrun", "Don't alter IMAP account or registry") { @opts[:simulate] = true }
        opts.on("-t", "--throttle-ignore", "Disable IMAP throttle detection") { @opts[:throttle_detect] = false }
        opts.on("-m", "--monochrome", "Don't colorize output") { logger.colorize = false }
        opts.on("-h", "--help", "Shows this help") { @opts[:dispatch] = :help }
        opts.on("-v", "--version", "Shows version and other info") { @opts[:dispatch] = :info }
        opts.on("-z", "Do not check for updates on GitHub (with -v/--version)") { @opts[:check_for_updates] = false }
        opts.on("--shell", "Open pry shell (requires pry gem)") { @opts[:dispatch] = :shell }
        opts.on("--mailboxes", "List all availables mailboxes in your IMAP account") { @opts[:dispatch] = :mailboxes }
      end

      begin
        @optparse.parse!(@argv)
      rescue OptionParser::ParseError => e
        abort(e.message)
        dispatch(:help)
        exit 1
      end
    end

    def load_configuration!
      unless Thread.main[:app_config]
        Thread.main[:app_config] = @config = Configuration.new
        Thread.main[:app_rules] = @rules = Rules.new

        # load all configs
        app_config = "#{ROOT}/config/config.rb"
        require app_config
        r = Dir.glob("#{ROOT}/config/**/*.rb")
        r.delete(app_config)
        r.each {|f| require f }
      end
      Thread.main[:app_config]
    end

    def load_registry!
      load_configuration!
      @registry = Registry.new(ROOT.join(cfg("registry.file")), {
        lifetime: cfg("registry.client_lifetime"),
        soft_limit: cfg("limits.soft"),
        hard_limit: cfg("limits.hard"),
      })
    rescue
      abort "Registry file is not read-/writeable or corrupted (#{$!.message})", 1
    end

    def cfg key = nil, default = nil
      @config.get(["bfetch", key].compact.join("."), default)
    end

    def imap_search_headers
      [].tap do |r|
        if idh = cfg("identification_header")
          r << ["HEADER", idh, ""]
        end
        cfg("imap_search.headers").each do |a, b, c|
          r << [a, b, c || ""]
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
      end
    end

    def handle_throttle
      if @opts[:throttle_detect] && connection.instance_variable_get(:@parser).instance_variable_get(:@str)["THROTTLED"]
        @throttled ||= 1
        warn "The IMAP server (probably gmail) is throttling your account! (sleep #{@throttled * 5} seconds)"
        sleep @throttled * 5
        @throttled += 1
      else
        @throttled = nil
      end
    rescue NoMethodError
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
