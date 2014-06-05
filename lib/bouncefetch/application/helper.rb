module Bouncefetch
  class Application
    module Helper
      def imap_search_headers
        [].tap do |r|
          if idh = cfg("identification_header")
            r << ["HEADER", idh, ""]
          end
          cfg("imap.queries").each do |a, b, c|
            r << [a, b, c || ""]
          end
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

      def mid_expunge
        return if @opts[:simulate] || cfg("general.expunge_rate") == 0
        @mid_expunge ||= 0
        @mid_expunge += 1

        if @mid_expunge > cfg("general.expunge_rate") && connected?
          log(c("E", :yellow))
          connection.expunge
          logger.raw "\b \b#{c("E", :magenta)}"
          @mid_expunge = nil
        end
      end

      def log_perform_failsafe what, &block
        ret = nil
        logger.log_with_print do
          log "#{what} "
          begin
            ret = block.call
            logger.raw c("DONE", :green)
          rescue
            logger.raw c("FAILED (#{$!.message.strip})", :red)
          end
        end
        ret
      end

      def inspect_mail mail
        return unless opts[:inspect]
        logger.ensure_method(:puts) do
          log ""
          log c("=============================================", :blue)
          log "Type " << c("info", :magenta) << c(" to get a brief overview of the current mail.")
          log "Type " << c("now?", :magenta) << c(" to reload rules and check if mail matches now.")
          log "Type " << c("exit", :magenta) << c(" to reload the rules and continue.")
          log c("=============================================", :blue)
          mail.info
          log c("=============================================", :blue)
          mail.instance_eval { binding.pry(quiet: true) }
          reload_rules!
        end
      end

      def pause!
        unless @pause
          @pause = true
          logger.ensure_method(:puts) { logger.raw("") ; log "Finishing tasks..." }
        end
      end

      def shutdown! sig = "Shutting down"
        unless @shutdown
          @shutdown = true
          logger.ensure_method(:puts) { logger.raw("") ; warn "Stopping #{Process.pid} (#{sig})..." }
          may_exit if @paused
        end
      end

      def graceful_exit! code = 1
        graceful
        exit!(code)
      end

      def may_exit
        raise Interrupt if @shutdown
      end

      def may_pause
        if @pause
          @pause = false
          logger.ensure_method(:puts) { logger.raw("") ; log(c("Paused (press enter to continue)", :magenta)) }

          @paused = true
          STDIN.gets.chomp
          @paused = false
        end
      end

      def candidates_to_array candidates, rows = []
        [].tap do |ary|
          # header
          header = [].tap do |r|
            r << "reference"           if rows.include?("ref")
            r << "soft_bounces"        if rows.include?("sbounces")
            r << "hard_bounces"        if rows.include?("hbounces")
            r << "soft_bounce_dates"   if rows.include?("sbounces_dates")
            r << "hard_bounce_dates"   if rows.include?("hbounces_dates")
            r << "soft_bounce_reasons" if rows.include?("sbounces_reasons")
            r << "hard_bounce_reasons" if rows.include?("hbounces_reasons")
          end
          ary << header

          # candidates
          candidates.each do |candidate, data|
            row = [].tap do |r|
              r << candidate                         if rows.include?("ref")
              r << data[:hits][:soft].count          if rows.include?("sbounces")
              r << data[:hits][:hard].count          if rows.include?("hbounces")
              r << data[:hits][:soft].join("@@@")    if rows.include?("sbounces_dates")
              r << data[:hits][:hard].join("@@@")    if rows.include?("hbounces_dates")
              r << data[:reasons][:soft].join("@@@") if rows.include?("sbounces_reasons")
              r << data[:reasons][:hard].join("@@@") if rows.include?("hbounces_reasons")
            end
            ary << row
          end
        end
      end

      def candidates_to_csv candidates, rows = []
        CSV.generate do |csv|
          candidates_to_array(candidates, rows).each do |row|
            csv << row
          end
        end
      end

      def candidates_to_json candidates, rows = []

      end
    end
  end
end
