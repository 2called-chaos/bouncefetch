module Bouncefetch
  class Rule
    attr_reader :cond, :crosscheck, :opts

    def initialize condition, crosscheck = true, opts = {}
      @opts = { downcase: true, oneline: false, squish: true }.merge(opts)
      @cond = condition
      @crosscheck = crosscheck
    end

    def normalized_body mail, plain = false
      r = mail.body.decoded.force_encoding("UTF-8")
      r = r.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: ' ')
      r = r.downcase if !plain && @opts[:downcase]
      r = r.gsub("=\n", "").squish if !plain && @opts[:squish]
      r = r.tr("\n", " ").tr("\r", "") if !plain && @opts[:oneline]
      r
    end

    def match? mail
      case @cond
        when String       then normalized_body(mail)[@cond.to_s.downcase]
        when Regexp       then normalized_body(mail, true).match(@cond)
        when Proc, Lambda then @cond[mail, normalized_body(mail)]
        else raise(ArgumentError, "unknown condition type #{@cond.class}")
      end
    end
  end
end
