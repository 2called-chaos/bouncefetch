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

    def plog msg, color = :yellow
      app.log app.c("#{msg}", color)
    end

    def handle! mode = :soft, rule
      cid = candidate
      if cid.present?
        plog "X", :green
        app.stats.send("handled_#{mode}_bounces", +1)
        app.registry.handle(candidate, mode, raw.date, rule)
        delete! if app.cfg("imap.remove_processed")
      else
        plog "X", :red
        app.stats.send("unidentifyable_bounces", +1)
      end
    end

    def ignore! delete = true
      plog "."
      app.stats.ignored_mails +1
      delete! if delete && app.cfg("imap.remove_processed")
    end

    def delete! expunge = false
      plog "%", :red
      unless app.opts[:simulate]
        app.connection.uid_store(uid, "+FLAGS", [:Deleted])
        app.connection.expunge if expunge
      end
      app.stats.deleted_mails +1
      true
    end

    def nocrosscheck!
      plog "§", :blue
      app.stats.no_crosscheck_matched +1
    end

    def unmatched!
      plog "?", :blue
      app.stats.unhandled_mails +1
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
        end
      end

      result && cross_checks && !crosscheck_match? ? nil : result
    end
  end
end
