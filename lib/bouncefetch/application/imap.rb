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

      def muid_singleton
        @muid_singleton ||= []
      end

      def delete_buffer
        @delete_buffer ||= []
      end

      def imap_bulk_expunge
        return if delete_buffer.empty?
        to_remove = delete_buffer.clone
        @delete_buffer.clear
        connection.uid_store(to_remove, "+FLAGS", [:Deleted])
        connection.expunge
      end

      def imap_bulk_delete ids, force = false
        [*ids].each{ |i| delete_buffer << i }
        imap_bulk_expunge if force
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
            # prevent idle timeout?
            Thread.new do
              loop do
                connection.list('', '*')
                sleep 60
              end
            end
            logger.raw c("DONE", :green)
          rescue Errno::ECONNREFUSED, Net::IMAP::NoResponseError, SocketError
            failed = true
            logger.raw c("FAILED (#{$!.message.strip})", :red)
          end
        end
        abort("Failed to connect to IMAP server, abort", 1) if failed || !imap
        imap
      end

      def imap_search query
        connection.uid_search(query)
      end
    end
  end
end
