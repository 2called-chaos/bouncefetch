module Bouncefetch
  class Rule
    attr_reader :cond, :crosscheck, :opts

    def initialize condition, crosscheck = true, opts = {}
      @opts = { downcase: true, oneline: false, squish: true }.merge(opts)
      @cond = condition
      @crosscheck = crosscheck
    end

    def body_cache_id plain = false
      @opts.slice(:downcase, :oneline, :squish).merge(plain: plain).to_json
    end

    def normalized_body mail, plain = false, cache = nil
      if cache && cached_body = cache[body_cache_id(plain)]
        return cached_body
      end
      r = mail.body.decoded.to_s.dup.force_encoding("UTF-8")
      r = r.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: ' ')
      r = r.gsub("=\n", "") # soft line breaks
      r = r.downcase if !plain && @opts[:downcase]
      r = r.squish if !plain && @opts[:squish]
      r = r.tr("\n", " ").tr("\r", "") if !plain && @opts[:oneline]
      return cache[body_cache_id(plain)] = r.freeze if cache
      r
    end

    def match? mail, cache = nil
      case @cond
        when String       then normalized_body(mail, false, cache)[@cond.to_s.downcase]
        when Regexp       then normalized_body(mail, true, cache).match(@cond)
        when Proc, Lambda then @cond[mail, normalized_body(mail, false, cache)]
        else raise(ArgumentError, "unknown condition type #{@cond.class}")
      end
    end
  end
end
