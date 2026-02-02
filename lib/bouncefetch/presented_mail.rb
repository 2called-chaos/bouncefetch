# frozen_string_literal: true

module Bouncefetch
  class PresentedMail < ::Mail::Message
    def initialize *args, **kw, &block
      @bb_stats = kw.delete(:bb_stats)
      @bb_cache = {}
      super
    end

    def normalized_subject
      @bb_cache[:normalized_subject] ||= @bb_stats.benchmark(:rt_content) do
        subject.to_s.force_encoding("UTF-8").squish
      end
    end
    alias_method :subjectN, :normalized_subject

    def downcased_subject
      @bb_cache[:downcased_subject] ||= @bb_stats.benchmark(:rt_content) do
        normalized_subject.downcase
      end
    end
    alias_method :subjectD, :downcased_subject

    # ---

    # rubocop:disable Performance/StringReplacement
    def normalized_body
      @bb_cache[:normalized_body] ||= @bb_stats.benchmark(:rt_content) do
        tmp = body.decoded.to_s.dup
        # tmp = tmp.force_encoding("UTF-8")
        tmp.encode!("UTF-8", "binary", invalid: :replace, undef: :replace, replace: " ")
        tmp.gsub!(" ", "")
        tmp.gsub!("=\n", "") # soft line breaks
        tmp
      end
    end
    alias_method :bodyN, :normalized_body
    # rubocop:enable Performance/StringReplacement

    def downcased_body
      @bb_cache[:downcased_body] ||= @bb_stats.benchmark(:rt_content) { normalized_body.downcase }
    end
    alias_method :bodyD, :downcased_body

    def stripped_body
      @bb_cache[:stripped_body] ||= @bb_stats.benchmark(:rt_content) do
        tmp = normalized_body.gsub(/<("[^"]*"|'[^']*'|[^'">])*>/, "")
        tmp.strip!
        CGI.unescapeHTML(tmp)
      end
    end
    alias_method :bodyS, :stripped_body

    def stripped_downcased_body
      @bb_cache[:stripped_downcased_body] ||= @bb_stats.benchmark(:rt_content) { stripped_body.downcase }
    end
    alias_method :bodySD, :stripped_downcased_body
  end
end
