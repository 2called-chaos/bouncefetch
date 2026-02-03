# frozen_string_literal: true

module Bouncefetch
  class Rule
    attr_reader :cond, :on, :crosscheck, :opts, :stats, :source_location

    def initialize *args, on: :body, crosscheck: true, body: nil, subject: nil, source_location: nil, **opts, &block
      @opts = { downcase: true, oneline: false, squish: true }.merge(opts)
      @stats = Hash.new(0)
      @source_location = source_location
      @crosscheck = crosscheck
      @on = on

      if block
        @cond = block
      elsif body
        @cond = body
        @on = :body
      elsif subject
        @cond = subject
        @on = :subject
      elsif args.length > 0
        # warn "Deprecation: please pass either body: or subject: keyword argument for condition"
        @cond = args.shift
      end

      if args.length > 0 && (args.last.is_a?(TrueClass) || args.last.is_a?(FalseClass))
        Thread.main.app_logger.ensure_method(:puts) do
          Thread.main.app_logger.info "Deprecation: #{args.last} passed to rule, please use crosscheck: keyword argument (in #{source_location&.join(":") || "???"})"
        end
        @crosscheck = args.shift
      end

      @cond = @cond.downcase if @cond.is_a?(String) && @opts[:downcase]
    end

    def cache_id
      @opts.slice(:downcase, :oneline, :squish).merge(on: @on).to_json
    end

    def normalized_value mail, plain: false, cache: nil
      if @on == :body
        return mail.normalized_body if plain

        if cache && (cid = cache_id) && cached_value = cache[cid]
          return cached_value
        end

        r = @opts[:downcase] ? mail.downcased_body : mail.normalized_body
        r = r.squish if @opts[:squish]
        r = r.tr("\n", " ").tr("\r", "") if @opts[:oneline]

        cache ? cache[cid] = r.freeze : r
      elsif @on == :subject
        return mail.normalized_subject if plain

        if cache && (cid = cache_id) && cached_value = cache[cid]
          return cached_value
        end

        r = @opts[:downcase] ? mail.downcased_subject : mail.normalized_subject
        r = r.squish if @opts[:squish]
        r = r.tr("\n", " ").tr("\r", "") if @opts[:oneline]

        cache ? cache[cid] = r.freeze : r
      end
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
      if mail.multipart? && @on == :body
        mail.parts.any? do |part|
          match_without_stats?(part, cache) if part.text? || part.content_type == "message/delivery-status"
        end
      else
        case @cond
          when String then normalized_value(mail, cache: cache)[@cond]
          when Regexp then normalized_value(mail, cache: cache).match(@cond)
          when Proc   then @cond[mail, normalized_value(mail, cache: cache), self]
          else raise(ArgumentError, "unknown condition type #{@cond.class}")
        end
      end
    end
  end
end
