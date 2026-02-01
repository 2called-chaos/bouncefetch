# Encoding: utf-8
module Bouncefetch
  class PresentedMail < ::Mail::Message
    def initialize *args, **kw, &block
      super
      @bb_cache = {}
    end

    def normalized_subject
      @bb_cache[:normalized_subject] ||= begin
        m.subject.to_s.force_encoding("UTF-8").squish
      end
    end
    alias_method :subjectN, :normalized_subject

    def downcased_subject
      @bb_cache[:downcased_subject] ||= begin
        normalized_subject.downcase
      end
    end
    alias_method :subjectD, :downcased_subject

    # ---

    def normalized_body
      @bb_cache[:normalized_body] ||= begin
        raw.body.decoded
          .to_s.dup
          .force_encoding("UTF-8")
          .encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: " ")
          .gsub("=\n", "") # soft line breaks
      end
    end
    alias_method :bodyN, :normalized_body

    def downcased_body
      @bb_cache[:downcased_body] ||= normalized_body.downcase
    end
    alias_method :bodyD, :downcased_body

    def stripped_body
      @bb_cache[:stripped_body] ||= begin
        CGI.unescapeHTML(normalized_body.gsub(/<("[^"]*"|'[^']*'|[^'">])*>/, "").gsub(" ", "").gsub("=\n", "").strip)
      end
    end
    alias_method :bodyS, :stripped_body

    def stripped_downcased_body
      @bb_cache[:stripped_downcased_body] ||= stripped_body.downcase
    end
    alias_method :bodySD, :stripped_downcased_body
  end
end
