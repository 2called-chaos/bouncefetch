# Encoding: Utf-8
module Bouncefetch
  class Application
    module Dispatch
      def dispatch action = (@opts[:dispatch] || :help)
        case action
          when :version, :info then dispatch_info
          else
            if respond_to?("dispatch_#{action}")
              send("dispatch_#{action}")
            else
              abort("unknown action #{action}", 1)
            end
        end
      end

      def graceful &block
        begin
          block.call
        ensure
          # graceful shutdown
          begin
            unless @opts[:simulate]
              connection.expunge if connected?
              @registry.try(:save)
            end
          rescue ; end
          begin ; connection.logout if connected? ; rescue ; end
          begin ; connection.disconnect if connected? ; rescue ; end
        end
      end

      def dispatch_help
        logger.log_without_timestr do
          @optparse.to_s.split("\n").each(&method(:log))
          log ""
          log "Config directory: " << c("#{ROOT}/config", :magenta)
          log ""
          log "Legend:"
          log "  " << c("X", :green) << c(" handled mails")
          log "  " << c("X", :red) << c(" handled but client not identifyable")
          log "  " << c(".", :yellow) << c(" ignored")
          log "  " << c("%", :red) << c(" deleted (follows ") << c("X", :green) << c(" or ") << c(".", :yellow) << c(")")
          log "  " << c("?", :blue) << c(" unmatched")
          log "  " << c("§", :blue) << c(" no matching crosscheck")
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
              require "net/http"
              log c("checking...", :blue)

              begin
                current_version = Gem::Version.new Net::HTTP.get_response(URI.parse(Bouncefetch::UPDATE_URL)).body.strip

                if current_version > your_version
                  status = c("#{current_version} (consider update)", :red)
                elsif current_version < your_version
                  status = c("#{current_version} (ahead, beta)", :green)
                else
                  status = c("#{current_version} (up2date)", :green)
                end
              rescue
                status = c("failed (#{$!.message})", :red)
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

      def dispatch_list_candidates
        load_configuration!
        load_registry!

        graceful do
          items = registry.reached_limit
          if items.any?
            logger.log_without_timestr do
              log [
                "reference",
                "soft_bounces",
                "hard_bounces",
                "soft_bounce_dates",
                "hard_bounce_dates",
                "soft_bounce_reasons",
                "hard_bounce_reasons",
              ].join("|")
              items.each do |candidate, data|
                log [
                  candidate,
                  data[:hits][:soft].count,
                  data[:hits][:hard].count,
                  data[:hits][:soft].join("@@@"),
                  data[:hits][:hard].join("@@@"),
                  data[:reasons][:soft].join("@@@"),
                  data[:reasons][:hard].join("@@@"),
                ].join("|")
              end
            end
          end
        end
      end

      def dispatch_statistics
        load_configuration!
        load_registry!

        puts "moep"
      end

      def dispatch_export
        load_configuration!
        load_registry!

        puts "moep"
      end

      def dispatch_export_remote
        load_configuration!
        load_registry!

        puts "moep"
      end

      def dispatch_mailboxes
        load_configuration!
        load_registry!

        graceful do
          connection # connect and authorize imap
          connection.list('*', '*').each{|m| log c("#{m.name}", :magenta) }
        end
      end

      def dispatch_shell
        load_configuration!
        load_registry!

        graceful do
          connection # connect and authorize imap
          log "Type " << c("exit", :magenta) << c(" to end the session.")
          log "Type " << c("exit!", :magenta) << c(" to terminate session (escape loop). WARNING: No graceful shutdown!")
          log "You have the following local variables: " << c("connection, config, registry, opts", :magenta)
          binding.pry(quiet: true)
        end
      end

      def dispatch_index
        load_configuration!
        load_registry!

        graceful do
          mailboxes = cfg("imap.mailboxes")
          connection # connect and authorize imap

          begin
            mailboxes.each_with_index do |mailbox, i|
              # select mailbox
              logger.log_with_print do
                log "Selecting #{i+1}/#{mailboxes.count} " << c("#{mailbox}", :magenta) << c("... ")
                begin
                  connection.select(mailbox)
                  logger.raw c("OK", :green)
                rescue Net::IMAP::NoResponseError
                  logger.raw c("FAILED (#{$!.message.strip})", :red)
                end
              end

              # search emails
              logger.log_with_print do
                logger.log_without_timestr do
                  imap_search_headers.each do |query|
                    imap_search(query) do |mail|
                      handle_throttle
                      handle_mail(mail)
                    end
                  end
                end
              end

              # pre expunge
              connection.expunge if !@opts[:simulate] && connected?
            end

            log c("All finished!", :green)
          ensure
            log ""
            @stats.render.each {|l| log(l) }
          end
        end
      end
    end
  end
end
