# frozen_string_literal: true

module Bouncefetch
  module PresentedMessage
    def normalized_subject
      @bb_cache[:normalized_subject] ||= @bb_stats.benchmark(:rt_content) do
        subject.to_s.squish
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
        begin
          tmp = (multipart? ? text_part : body).decoded.to_s.dup
          tmp = tmp.force_encoding("UTF-8")
          #tmp.encode!("UTF-8", "binary", invalid: :replace, undef: :replace, replace: " ")
          tmp.gsub!(" ", "")
          tmp.gsub!("=\n", "") # soft line breaks
          tmp.tap(&:downcase) # trigger invalid input validation
        rescue StandardError => ex
          Thread.new{`say -v Zarvox Pry is ready`} ; ::Kernel.binding.pry; 1+1
          tmp = body.decoded.to_s.dup
          #tmp = tmp.force_encoding("UTF-8")
          tmp.encode!("UTF-8", invalid: :replace, undef: :replace, replace: " ")
          tmp.gsub!(" ", "")
          tmp.gsub!("=\n", "") # soft line breaks
          tmp
        end
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
        tmp = CGI.unescapeHTML(normalized_body)
        tmp.gsub!(/<("[^"]*"|'[^']*'|[^'">])*>/, "")
        tmp.squish!
        tmp
      end
    end
    alias_method :bodyS, :stripped_body

    def stripped_downcased_body
      @bb_cache[:stripped_downcased_body] ||= @bb_stats.benchmark(:rt_content) { stripped_body.downcase }
    end
    alias_method :bodySD, :stripped_downcased_body
  end
end
