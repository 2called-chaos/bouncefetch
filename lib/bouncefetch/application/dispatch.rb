# frozen_string_literal: true

module Bouncefetch
  class Application
    module Dispatch
      def dispatch action = @opts[:dispatch] || :help
        case action
          when :version, :info then dispatch_info
          else
            if respond_to?("dispatch_#{action}")
              send("dispatch_#{action}")
            else
              abort("unknown action #{action}", exit: 1)
            end
        end
      end

      def graceful opts = {}, &block
        begin
          opts = { expunge: true, registry: true }.merge(opts)
          block&.call
        ensure
          # graceful shutdown
          unless @opts[:simulate]
            log_perform_failsafe("Performing IMAP expunge...") { imap_bulk_expunge } if opts[:expunge] && connected?
            log_perform_failsafe("Saving registry...") { @registry.save } if opts[:registry] && @registry
          end
          log_perform_failsafe("IMAP logout...") { connection.logout } if connected?
          log_perform_failsafe("IMAP disconnect...") { connection.disconnect } if connected?
        end
      end

      def dispatch_help_short
        logger.log_without_timestr do
          @optparse.to_s.split("\n").each{ log(_1) }
        end
      end

      def dispatch_upgrade
        log c("You're running #{Bouncefetch::VERSION}", :blue)

        # git pull
        log "Pull latest changes..."
        system %{cd "#{Bouncefetch::ROOT}" && git pull}

        # bundle
        log "Installing bundle..."
        system %{cd "#{Bouncefetch::ROOT}" && bundle install}

        log c("You're now running #{File.read("#{Bouncefetch::ROOT}/VERSION")}", :blue)
      end

      def dispatch_help
        logger.log_without_timestr do
          @optparse.to_s.split("\n").each{ log(_1) }

          log ""
          log "Config directory: #{c("#{ROOT}/config", :magenta)}"
          log ""
          log "Legend:"
          log c("  X  ", :green) << c("handled mails")
          log c("  X  ", :red) << c("handled but client not identifyable")
          log c("  .  ", :yellow) << c("ignored")
          log c("  %  ", :red) << c("deleted (follows ") << c("X", :green) << c(" or ") << c(".", :yellow) << c(")")
          log c("  ?  ", :blue) << c("unmatched")
          log c("  §  ", :blue) << c("no matching crosscheck")
          log c("  E  ", :magenta) << c("performing IMAP expunge (delete marked mails)")
        end
      end

      def dispatch_info
        logger.log_without_timestr do
          log ""
          log "     Your version: #{your_version = Gem::Version.new(Bouncefetch::VERSION)}"

          # get current version
          logger.log_with_print do
            log "  Current version: "
            if @opts[:check_for_updates]
              log c("checking...", :blue)

              status = begin
                current_version = Gem::Version.new Net::HTTP.get_response(URI.parse(Bouncefetch::UPDATE_URL)).body.strip

                if current_version > your_version
                  c("#{current_version} (consider update)", :red)
                elsif current_version < your_version
                  c("#{current_version} (ahead, beta)", :green)
                else
                  c("#{current_version} (up2date)", :green)
                end
              rescue StandardError => ex
                c("failed (#{ex.message})", :red)
              end

              logger.raw "#{"\b" * 11}#{" " * 11}#{"\b" * 11}", :print # reset cursor
              log status
            else
              log c("check disabled", :red)
            end
          end

          # more info
          log ""
          log "  Bouncefetch is brought to you by #{c "bmonkeys.net", :green}"
          log "  Contribute @ #{c "github.com/2called-chaos/bouncefetch", :cyan}"
          log "  Eat bananas every day!"
          log ""
        end
      end

      def dispatch_statistics
        load_configuration!
        load_registry!

        log_perform_failsafe("Loading statistics") { @registry_stats = @registry.stats }
        longest_key = @registry_stats.keys.map{|s| s.to_s.length }.max

        log ""
        @registry_stats.each do |key, val|
          val1, val2 = val
          log c("#{key}: ".rjust(longest_key + 2, " "), :blue) << [c("#{val1}", val2 ? :magenta : :yellow), c("#{val2}", :yellow)].join(" ")
        end
        log ""
      end

      def dispatch_list_candidates
        load_configuration!
        load_registry!

        graceful expunge: false, registry: false do
          items = registry.reached_limit
          if items.any?
            log "Found " << c("#{items.count}", :magenta) << c(" candidates.")
            logger.log_without_timestr do
              candidates_to_array(items, opts[:export_columns]).each_with_index do |row, i|
                if i == 0
                  logger.raw row.map{|r| c(r, :blue) }.join(c("|", :red))
                else
                  logger.raw row.join(c("|", :red))
                end
              end
            end
          else
            log "No candidates found."
          end
        end
      end

      def dispatch_export
        load_configuration!
        load_registry!

        graceful expunge: false do
          result_file = File.expand_path(opts[:remote])
          items = registry.reached_limit
          log "Found " << c("#{items.count}", :magenta) << c(" candidates.")

          csv = log_perform_failsafe("Generating CSV") { candidates_to_csv(items, opts[:export_columns]) }

          # check if file exists
          if FileTest.exists?(result_file)
            warn "Target file already exists!"
            q = ask "Overwrite file? [yn]" until "#{q}".downcase.start_with?("y", "n")
            exit 1 if q.downcase.start_with?("n")
          end

          # write to file
          write_succeeded = false
          log_perform_failsafe("Writing CSV to file") do
            File.binwrite(result_file, csv)
            write_succeeded = true
          end
          if !opts[:simulate] && write_succeeded
            log_perform_failsafe("Removing candidates from registry") do
              items.each_key {|candidate| registry.remove(candidate) }
            end
          end
        end
      end

      def dispatch_export_remote
        load_configuration!
        load_registry!

        graceful expunge: false do
          items = registry.reached_limit
          log "Found " << c("#{items.count}", :magenta) << c(" candidates.")

          # Post to remote
          post_succeeded = false
          log_perform_failsafe("POSTing data to remote endpoint...") do
            json_data = candidates_to_json(items, opts[:export_columns])
            if opts[:deflate_json]
              json_data = Base64.strict_encode64(Zlib::Deflate.deflate(json_data))
            end
            res = Net::HTTP.post_form URI(opts[:remote]), { "candidates" => json_data }
            raise "server responded with status code #{res.code}" if res.code.to_i != 200

            post_succeeded = true
          end

          if !opts[:simulate] && post_succeeded
            log_perform_failsafe("Removing candidates from registry") do
              items.each_key {|candidate| registry.remove(candidate) }
            end
          end
        end
      end

      def dispatch_mailboxes
        load_configuration!

        graceful expunge: false do
          connection # connect and authorize imap
          connection.list("", "*").each{|m| log c("#{m.name}", :magenta) }
        end
      end

      def dispatch_shell
        load_configuration!
        load_registry!

        graceful do
          connection # connect and authorize imap
          log "Type #{c("exit", :magenta)} #{c(" to gracefully end the session.")}"
          log "Type #{c("exit!", :magenta)} #{c(" to terminate session (escape loop).")} #{c(" WARNING: No graceful shutdown!", :red)}"
          log "Type #{c("graceful_exit!", :magenta)} #{c(" to gracefully terminate session (escape loop).")}"
          log "You have the following local variables: #{c("connection, config, registry, opts", :magenta)}"
          log "You can save the registry with #{c("registry.save", :magenta)} #{c(" and reload it with ")} #{c("registry.load!", :magenta)}"
          binding.respond_to?(:pry) ? binding.pry(quiet: true) : binding.irb
        end
      end

      def dispatch_index
        load_configuration!
        load_registry!
        enable_signal_trapping!

        graceful do
          mailboxes = cfg("imap.mailboxes")
          connection # eager imap connect and authorize

          begin
            mailboxes.each_with_index do |mailbox, i|
              next unless imap_select_mailbox(mailbox, status: "#{i + 1}/#{mailboxes.length}")

              all_handled = 0
              logger.log_with_print(clear: !logger.debug?) do
                logger.log_without_timestr do
                  # search emails
                  imap_search_headers.each do |query|
                    logger.log_with_timestr { debug c("% #{query} ", :black) }
                    handled, list = 0, imap_search(query)
                    logger.debug c("#{list.length} messages\n", :blue)

                    list.each do |message_id|
                      begin
                        may_pause
                        may_exit
                        mid_expunge
                        handle_throttle
                        # unless muid_singleton.include?(message_id)
                        #   muid_singleton << message_id
                        #   handle_mail(BBMail.new(self, message_id))
                        # end
                        handle_mail(BBMail.new(self, message_id))
                        handled += 1
                        all_handled += 1
                        break if $force_shutdown
                      rescue StandardError => ex
                        warn "#{"\n" if handled > 0}failed to load mail #{message_id} - #{ex.message}\n"
                      end
                    end
                    break if $force_shutdown

                    # expunge before performing another query
                    mid_expunge(force: true) if handled > 0

                    log "\n" if handled > 0 && logger.debug?
                  end

                  # expunge before selecting another mailbox
                  mid_expunge(force: true) if all_handled > 0
                end
              end

              break if $force_shutdown
            end

            log c("All finished!", :green)
          ensure
            log ""
            @stats.render.each {|l| log(l) }

            if Thread.main[:app_benchmark_rules]
              if cfg("print_rules_benchmark")
                log ""
                sorted_rule_benchmarks(csv: ROOT.join(cfg("csv_rules_benchmark"))) do |sid, stat|
                  puts "#{c("#{stat[:type]}", :magenta)} #{c(stat[:cond], :blue)} #{c(stat[:source_location].gsub(ROOT.to_s, "~bouncefetch~/"), :black) if stat[:source_location]}"
                  stat.except(:type, :cond).each do |k, v|
                    puts "    #{c(v.to_s.rjust(8), :yellow)} #{c(k, :cyan)}"
                  end
                end
              elsif cfg("csv_rules_benchmark")
                sorted_rule_benchmarks(csv: ROOT.join(cfg("csv_rules_benchmark")))
              end
            end
          end
        end
      end
    end
  end
end
