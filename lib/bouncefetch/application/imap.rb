# Encoding: Utf-8
module Bouncefetch
  class Application
    module Imap
      def connection
        @connection ||= imap_connect
      end

      def connected?
        !!@connection
      end

      def imap_connect
        imap, failed = nil, false
        logger.log_with_print do
          log "Connecting to IMAP server... "
          begin
            ssl = cfg("imap.ssl", false)
            port = cfg("imap.port", ssl ? 993 : 143)
            imap = Net::IMAP.new(cfg("imap.hostname"), port: port, ssl: ssl)
            if cfg("imap.use_auth", true)
              imap.authenticate(cfg("imap.method", "LOGIN"), cfg("imap.username"), cfg("imap.password"))
            else
              imap.login(cfg("imap.username"), cfg("imap.password"))
            end
            logger.raw c("DONE", :green)
          rescue Errno::ECONNREFUSED, Net::IMAP::NoResponseError
            failed = true
            logger.raw c("FAILED (#{$!.message.strip})", :red)
          end
        end
        abort("Failed to connect to IMAP server, abort", 1) if failed || !imap
        imap
      end

      def imap_search query, &block
        connection.uid_search(query).each do |message_id|
          instance_exec(BBMail.new(self, message_id), &block)
        end
      end
    end
  end
end
