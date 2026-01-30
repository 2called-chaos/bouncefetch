# frozen_string_literal: true

module Bouncefetch
  class Rule
    attr_reader :cond, :crosscheck, :opts, :stats

    def initialize condition, crosscheck = true, opts = {}
      @opts = { downcase: true, oneline: false, squish: true }.merge(opts)
      @cond = condition
      @crosscheck = crosscheck
      @stats = Hash.new(0)
    end

    def body_cache_id plain = false
      @opts.slice(:downcase, :oneline, :squish).merge(plain: plain).to_json
    end

    def normalized_body mail, plain = false, cache = nil
      if cache && cached_body = cache[body_cache_id(plain)]
        return cached_body
      end

      r = mail.body.decoded.to_s.dup.force_encoding("UTF-8")
      r = r.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: " ")
      r = r.gsub("=\n", "") # soft line breaks
      r = r.downcase if !plain && @opts[:downcase]
      r = r.squish if !plain && @opts[:squish]
      r = r.tr("\n", " ").tr("\r", "") if !plain && @opts[:oneline]

      cache ? cache[body_cache_id(plain)] = r.freeze : r
    end

    def match? *args, **kw
      return match_without_stats?(*args, **kw) unless Thread.main[:app_benchmark_rules]

      result = nil
      @stats[:invocations] += 1

      @stats[:rt] += Benchmark.realtime do
        result = match_without_stats?(*args, **kw)
      end

      @stats[result ? :hit : :miss] += 1
      result
    end

    def match_without_stats? mail, cache = nil
      case @cond
        when String       then normalized_body(mail, false, cache)[@cond.to_s.downcase]
        when Regexp       then normalized_body(mail, true, cache).match(@cond)
        when Proc, Lambda then @cond[mail, normalized_body(mail, false, cache)]
        else raise(ArgumentError, "unknown condition type #{@cond.class}")
      end
    end
  end
end
