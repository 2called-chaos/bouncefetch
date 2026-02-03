# frozen_string_literal: true

module Bouncefetch
  class BBMail
    attr_reader :uid, :raw, :app, :cache

    def initialize app, uid
      @app, @uid = app, uid
      @cache = {}
      app.stats.mails_checked(+1)
      load!
    end

    def load!
      fetchdata = app.with_connection{|imap| imap.uid_fetch(uid, "RFC822")[0] }
      @raw = _present_mail Mail.new(fetchdata.attr["RFC822"])
    end

    def _present_mail mail
      mail.instance_variable_set(:@bb_stats, app.stats)
      mail.instance_variable_set(:@bb_cache, {})
      mail.extend(PresentedMessage)
      _present_mail_parts(mail) if mail.multipart?

      mail
    end

    def _present_mail_parts parent
      parent.parts.each do |part|
        if part.multipart?
          _present_mail_parts(part)
        else
          part.instance_variable_set(:@bb_stats, app.stats)
          part.instance_variable_set(:@bb_cache, {})
          part.extend(PresentedMessage)
        end
      end
    end

    def plog msg, color = :yellow
      app.log app.c("#{msg}", color)
    end

    def handle! mode = :soft, rule = nil, ignore_missing_ref: false
      cid = candidate
      if cid.present?
        plog "X", :green
        app.stats.send("handled_#{mode}_bounces", +1)
        app.registry.handle(cid, mode, raw.date, rule)
        delete! if app.cfg("general.remove_processed")
      elsif ignore_missing_ref
        plog "X", :yellow
        app.stats.ignored_mails(+1)
        delete! if app.cfg("general.remove_processed")
      else
        plog "X", :red
        app.stats.unidentifyable_bounces(+1)
        app.inspect_mail(self)
      end
    end

    def ignore! delete: true
      plog "."
      app.stats.ignored_mails(+1)
      delete! if delete && app.cfg("general.remove_processed")
    end

    def delete! expunge: false
      plog "%", :red
      unless app.opts[:simulate]
        app.imap_bulk_delete(uid, force: expunge)
      end
      app.stats.deleted_mails(+1)
    end

    def nocrosscheck!
      plog "§", :blue
      app.stats.no_crosscheck_matched(+1)
      app.inspect_mail(self)
    end

    def unmatched!
      plog "?", :blue
      app.stats.unhandled_mails(+1)
      app.inspect_mail(self)
    end

    # try to find client candidates, not really sophisticated :)
    def candidate
      result = nil
      if header = app.cfg("identification_header").presence
        begin
          header_match = raw.body.to_s.match(/#{header}:( )(?<value>.*)/i)
          result = header_match.named_captures["value"]&.strip if header_match
        rescue StandardError => ex
          plog "<CandidateError:#{ex.class}: #{ex.message}>", :red
        end
      end
      result ||= raw.header["X-Failed-Recipients"]&.value
      result
    end

    def crosscheck_match?
      rules = app.rules.get("bfetch.crosschecks.rules", [])
      rules.blank? || rules.any? {|rule| rule.match?(@raw) }
    end

    def match cross_checks: true
      app.stats.benchmark(:rt_rules) do
        result = false

        app.rules.get("bfetch").each do |type, store|
          next if type.to_sym == :crosschecks

          rules = store[:rules] || []
          rules.each do |rule|
            result = [type, rule] if rule.match?(@raw, cache)
            break if result
          end
          break if result
        end

        result && cross_checks && result[1].crosscheck && !crosscheck_match? ? nil : result
      end
    end

    def _snip_body body, limit: 750
      if ix = body.index("------ This is a copy of the message, including all the headers. ------")
        body[0..(ix - 1)].strip
      else
        body[0..limit].strip
      end
    end

    def _parts_to_info parts, r, iscope: [], limit: 750
      parts.each_with_index do |p, i|
        isco = iscope + [i]

        if p.multipart?
          _parts_to_info(p.parts, r, limit: limit, iscope: isco)
        elsif p.text? || p.content_type == "message/delivery-status"
          r["Part #{isco.join("/")} (#{p.main_type})"] = _snip_body(p.body.to_s, limit: limit)
        end
      end
    end

    def info limit = 750
      info_data = {}.tap do |r|
        r["Matching"] = now?(reload_rules: true, to_log: false)
        r["Subject"] = raw.subject
        r["Multipart"] = raw.multipart?
        if raw.multipart?
          _parts_to_info(raw.parts, r, limit: limit)
        else
          r["Body"] = _snip_body(raw.body.to_s, limit: limit)
        end
      end

      longest_key = info_data.keys.map{|s| s.to_s.length }.max
      info_data.each do |key, val|
        val1, val2 = val
        app.log app.c("#{key}: ".rjust(longest_key + 2, " "), :blue) << [app.c("#{val1}", val2 ? :magenta : :yellow), app.c("#{val2}", :yellow)].join(" ")
      end
      nil
    end

    def now? reload_rules: true, to_log: true
      app.reload_rules! if reload_rules
      strr, res = "?", false
      case m = match
        when nil then strr = app.c("rule matched but no crosscheck", :magenta)
        when false then strr = app.c("no rule matches, crosscheck: #{crosscheck_match?}", :red)
        else
          type, rule = m
          strr = app.c("yes, #{type}: #{rule.cond}", :green)
          res = true
      end
      if to_log
        app.log strr
        res
      else
        strr
      end
    end

    def now!
      now?.tap{|r| throw(:inspect_escape, :retry_match) if r }
    end

    def del!
      delete!.tap{ throw(:inspect_escape) }
    end

    def shutdown
      $force_shutdown = true
      throw(:inspect_escape)
    end
  end
end
