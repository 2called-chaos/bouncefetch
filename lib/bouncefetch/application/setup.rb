module Bouncefetch
  class Application
    module Setup
      def initialize env, argv
        @env, @argv = env, argv
        @opts = {
          config_file: "config",
          dispatch: :index,
          check_for_updates: true,
          simulate: false,
          throttle_detect: true,
          inspect: false,
          export_columns: %w[ref sbounces hbounces sbounces_dates hbounces_dates sbounces_reasons hbounces_reasons],
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
          opts.banner = "\n    Usage: bouncefetch [options]"

          # general settings
          opts.separator("")
          opts.separator(c("    # General settings", :blue))
          opts.on("-d", "--dryrun", "Don't alter IMAP account or registry") { @opts[:simulate] = true }
          opts.on("-m", "--monochrome", "Don't colorize output") { logger.colorize = false }
          opts.on("-t", "--throttle-ignore", "Disable IMAP throttle detection") { @opts[:throttle_detect] = false }
          opts.on("-i", "--inspect", "Open pry shell for every mail which is unidentifyable, unmatched or has", "no matching crosscheck. Use --shell beforehand to get more help on pry.") { @opts[:inspect] = true }
          opts.on("--config NAME", String, "Use a different config file (default: config)") {|f| @opts[:config_file] = f }


          # stats / export
          opts.separator("")
          opts.separator(c("    # Registry & Export", :blue))
          opts.on("-s", "--statistics", "show statistics about the registry and candidates") { @opts[:dispatch] = :statistics }
          opts.on("-c", "--candidates", "list unsubscribe candidates (use export to get csv)") { @opts[:dispatch] = :list_candidates }
          opts.on("-e", "--export FILE", String, "export unsubscribe candidates to file and remove them from the registry", "use with --dryrun to not alter registry (same for --remote)") {|f| @opts[:dispatch] = :export ; @opts[:remote] = f }
          opts.on("-r", "--remote RESOURCE", String, "post unsubscribe candidates to URL and remove them from the registry", "refer to the readme for information about how we post the data") {|f| @opts[:dispatch] = :export_remote ; @opts[:remote] = f }
          opts.on("-o", "--output col1,col2", Array, "columns to include for --candidates --export --remote", "default: ref,sbounces,hbounces,sbounces_dates,hbounces_dates,sbounces_reasons,hbounces_reasons") {|f| @opts[:export_columns] = f }


          # misc actions
          opts.separator("")
          opts.separator(c("    # Miscellaneous", :blue))
          opts.on("-h", "--help", "Shows this help") { @opts[:dispatch] = :help }
          opts.on("-v", "--version", "Shows version and other info") { @opts[:dispatch] = :info }
          opts.on("-z", "Do not check for updates on GitHub (with -v/--version)") { @opts[:check_for_updates] = false }
          opts.on("--upgrade", "Update bouncefetch (only works with git)") { @opts[:dispatch] = :upgrade }
          opts.on("--mailboxes", "List all availables mailboxes in your IMAP account") { @opts[:dispatch] = :mailboxes }
          opts.on("--shell", "Open pry shell") { @opts[:dispatch] = :shell }
        end

        begin
          @optparse.parse!(@argv)
        rescue OptionParser::ParseError => e
          abort(e.message)
          dispatch(:help_short)
          exit 1
        end
      end

      def app_config_file
        fuzzy = Dir["#{ROOT}/config/*.rb"].select{|f| File.basename(f) =~ /#{@opts[:config_file]}/i }
        fuzzy.length == 1 ? fuzzy.first : "#{ROOT}/config/#{@opts[:config_file]}.rb"
      end

      def load_configuration!
        unless Thread.main[:app_config]
          log_perform_failsafe "Loading config and rules..." do
            Thread.main[:app_config] = @config = Configuration.new
            Thread.main[:app_rules] = @rules = Rules.new

            # load all configs
            load app_config_file
            r = Dir.glob("#{ROOT}/config/**/*rule*.rb")
            r.delete(app_config_file)
            r.each {|f| load f }
          end
        end
        Thread.main[:app_config]
      end

      def reload_rules!
        if Thread.main[:app_rules]
          @old_rules = @rules
          Thread.main[:app_rules] = @rules = nil
          log_perform_failsafe "Reloading rules..." do
            reload_rules!
          end
        else
          Thread.main[:app_rules] = @rules = Rules.new

          # load rules configs
          begin
            r = Dir.glob("#{ROOT}/config/**/*rule*.rb")
            r.delete(app_config_file)
            r.each {|f| load f }
          rescue
            Thread.main[:app_rules] = @rules = @old_rules
          end
        end
        Thread.main[:app_rules]
      end

      def cfg key = nil, default = nil
        @config.get(["bfetch", key].compact.join("."), default)
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

      def enable_signal_trapping!
        Signal.trap("INT") {|sig| shutdown! "#{Signal.signame(sig)}" }
        Signal.trap("TERM") {|sig| shutdown! "#{Signal.signame(sig)}" }
        Signal.trap("TSTP") {|sig| shutdown! "#{Signal.signame(sig)}" }
        Signal.trap("USR1") { pause! }
      end
    end
  end
end
