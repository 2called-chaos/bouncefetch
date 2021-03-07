# Encoding: utf-8
module Bouncefetch
  class BBMail
    attr_reader :uid, :raw, :app

    def initialize app, uid
      @app, @uid = app, uid
      app.stats.mails_checked +1
      load!
    end

    def load!
      fetchdata = app.connection.uid_fetch(uid, "RFC822")[0]
      @raw = Mail.new(fetchdata.attr["RFC822"])
    end

    def mbody stripped = false
      body = raw.body.decoded.force_encoding("UTF-8")
      if stripped
        body = body.gsub(/<("[^"]*"|'[^']*'|[^'">])*>/, "").gsub(" ", "").gsub("=\n", "").strip
      end
      body
    end

    def plog msg, color = :yellow
      app.log app.c("#{msg}", color)
    end

    def handle! mode = :soft, rule = nil, ignore_missing_ref = false
      cid = candidate
      if cid.present?
        plog "X", :green
        app.stats.send("handled_#{mode}_bounces", +1)
        app.registry.handle(cid, mode, raw.date, rule)
        delete! if app.cfg("general.remove_processed")
      else
        if ignore_missing_ref
          plog "X", :yellow
          app.stats.ignored_mails +1
          delete! if app.cfg("general.remove_processed")
        else
          plog "X", :red
          app.stats.unidentifyable_bounces +1
          app.inspect_mail(self)
        end
      end
    end

    def ignore! delete = true
      plog "."
      app.stats.ignored_mails +1
      delete! if delete && app.cfg("general.remove_processed")
    end

    def delete! expunge = false
      plog "%", :red
      unless app.opts[:simulate]
        app.imap_bulk_delete(uid, expunge)
      end
      app.stats.deleted_mails +1
      true
    end

    def nocrosscheck!
      plog "§", :blue
      app.stats.no_crosscheck_matched +1
      app.inspect_mail(self)
    end

    def unmatched!
      plog "?", :blue
      app.stats.unhandled_mails +1
      app.inspect_mail(self)
    end

    # try to find client candidates, not really sophisticated :)
    def candidate
      result = nil
      if header = app.cfg("identification_header").presence
        result = raw.body.to_s.match(/#{header}: (.*)/i)[1].strip rescue nil
      end
      result ||= raw.header["X-Failed-Recipients"].try(:value)
      result
    end

    def crosscheck_match?
      rules = app.rules.get("bfetch.crosschecks.rules", [])
      rules.blank? || rules.any? {|rule| rule.match?(@raw) }
    end

    def match? cross_checks = true
      result = false

      app.rules.get("bfetch").each do |type, store|
        next if type.to_sym == :crosschecks
        rules = store[:rules] || []
        rules.each do |rule|
          result = [type, rule] if rule.match?(@raw)
          break if result
        end
        break if result
      end

      result && cross_checks && result[1].crosscheck && !crosscheck_match? ? nil : result
    end

    def info limit = 750
      info_data = {}.tap do |r|
        r["Matching"] = now?(false, false)
        r["Subject"] = raw.subject
        r["Multipart"] = raw.multipart?
        if raw.multipart?
          raw.parts.each_with_index do |p, i|
            body = p.body.to_s
            if ix = body.index("------ This is a copy of the message, including all the headers. ------")
              r["Part #{i}"] = body[0..(ix-1)].strip
            else
              r["Part #{i}"] = body[0..limit].strip
            end
          end
        else
          body = raw.body.to_s
          if ix = body.index("------ This is a copy of the message, including all the headers. ------")
            r["Body (snip)"] = body[0..(ix-1)].strip
          else
            r["Body (snip)"] = body[0..limit].strip
          end
        end
      end

      longest_key = info_data.keys.map{|s| s.to_s.length }.max
      info_data.each do |key, val|
        val1, val2 = val
        app.log app.c("#{key}: ".rjust(longest_key + 2, " "), :blue) << [app.c("#{val1}", val2 ? :magenta : :yellow), app.c("#{val2}", :yellow)].join(" ")
      end
      nil
    end

    def now? reload_rules = true, to_log = true
      app.reload_rules! if reload_rules
      strr, res = "?", false
      case m = match?
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
