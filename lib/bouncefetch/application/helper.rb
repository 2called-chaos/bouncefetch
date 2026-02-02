# frozen_string_literal: true

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
        if @opts[:throttle_detect] && connection.instance_variable_get(:@parser)&.instance_variable_get(:@str)&.include?("THROTTLED")
          @throttled ||= 1
          warn "The IMAP server (probably gmail) is throttling your account! (sleep #{@throttled * 5} seconds)"
          sleep @throttled * 5
          @throttled += 1
        else
          @throttled = nil
        end
      end

      def mid_expunge force: false
        return if @opts[:simulate] || (!force && cfg("general.expunge_rate") == 0)

        @mid_expunge ||= 0
        @mid_expunge += 1

        return unless connected?
        return unless force || @mid_expunge > cfg("general.expunge_rate")

        log(c("E", :yellow))
        imap_bulk_expunge
        logger.raw "\b \b#{c("E", :magenta)}"
        @mid_expunge = nil
      end

      def log_perform_failsafe what, &block
        ret = nil
        logger.log_with_print do
          log "#{what} "
          begin
            ret = block.call
            logger.raw c("DONE", :green)
          rescue StandardError => ex
            logger.raw c("FAILED (#{ex.message.strip})", :red)
            ex.backtrace.each{|l| warn "  > #{l}" }
          end
        end
        ret
      end

      def inspect_mail mail
        return unless opts[:inspect]

        logger.ensure_method(:puts) do
          ENV["BF_CLEAR"] ? print(`clear`) : log("")
          log c("=============================================", :blue)
          log "Type #{c("info", :magenta)} #{c("to get a brief overview of the current mail.")}"
          log "Type #{c("now?", :magenta)} #{c(" to reload rules and check if mail matches now.")}"
          log "Type #{c("exit", :magenta)} #{c(" to reload the rules and continue.")}"
          log "Type #{c("shutdown", :magenta)} #{c(" to gracefully stop the app (save reg, etc.) - DON'T use `exit!'")}"
          log c("=============================================", :blue)
          mail.info
          log c("=============================================", :blue)

          sig = catch :inspect_escape do
            mail.instance_eval { binding.respond_to?(:pry) ? binding.pry(quiet: true) : binding.irb }
            reload_rules!
          end
          raise RetryMailMatchSignal if sig == :retry_match
        end
      end

      def pause!
        return if @pause

        @pause = true
        logger.ensure_method(:puts) { logger.raw("") ; log "Finishing tasks..." }
      end

      def shutdown! sig = "Shutting down"
        return if @shutdown

        @shutdown = true
        logger.ensure_method(:puts) { logger.raw("") ; warn "Stopping #{Process.pid} (#{sig})..." }
        may_exit if @paused
      end

      def graceful_exit! code = 1
        graceful
        exit!(code)
      end

      def may_exit
        raise Interrupt if @shutdown
      end

      def may_pause
        return unless @pause

        @pause = false
        logger.ensure_method(:puts) { logger.raw("") ; log(c("Paused (press enter to continue)", :magenta)) }

        @paused = true
        $stdin.gets.chomp
        @paused = false
      end

      def sorted_rule_benchmarks csv: nil, &each_result
        stats = {}
        rules.get("bfetch").each do |type, rdata|
          next unless rdata[:rules]

          rdata[:rules].each do |rule|
            sub = {}
            sub[:type] = type
            sub[:cond] = rule.cond.to_s
            sub[:invocations] = rule.stats[:invocations]
            sub[:miss] = rule.stats[:miss]
            sub[:hit] = rule.stats[:hit]
            sub[:rt] = rule.stats[:rt].round(6)
            sub[:rt_1k] = (rule.stats[:rt] / sub[:invocations].to_f) * 1000
            sub[:miss_rat] = (rule.stats[:miss] / rule.stats[:invocations].to_f).round(6)
            sub[:hit_rat] = (rule.stats[:hit] / rule.stats[:invocations].to_f).round(6)
            sub[:h2m_rat] = (rule.stats[:hit] / rule.stats[:miss].to_f).round(6)
            sub[:source_location] = rule.source_location&.join(":")
            stats["#{sub[:type]}|#{sub[:cond]}"] = sub.compact
          end
        end

        sorted = stats.sort_by{|k, r| r[:rt] }.to_h
        sorted.each(&each_result) if each_result

        CSV.open(csv, "wb") do |writer|
          writer << sorted.first[1].keys
          sorted.each_value{|data| writer << data.values }
        end if csv

        sorted
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
        items = {}
        candidates.each do |candidate, data|
          items[candidate] = {}.tap do |r|
            r["reference"] = candidate if rows.include?("ref")
            r["soft_bounces"] = data[:hits][:soft].count if rows.include?("sbounces")
            r["hard_bounces"] = data[:hits][:hard].count if rows.include?("hbounces")
            r["soft_bounce_dates"] = data[:hits][:soft] if rows.include?("sbounces_dates")
            r["hard_bounce_dates"] = data[:hits][:hard] if rows.include?("hbounces_dates")
            r["soft_bounce_reasons"] = data[:reasons][:soft] if rows.include?("sbounces_reasons")
            r["hard_bounce_reasons"] = data[:reasons][:hard] if rows.include?("hbounces_reasons")
          end
        end
        JSON.generate(items)
      end
    end
  end
end
