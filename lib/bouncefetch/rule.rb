module Bouncefetch
  class Rule
    attr_reader :cond

    def initialize condition
      @cond = condition
    end

    def match? mail
      case @cond
        when String       then mail.body.decoded.force_encoding("UTF-8").downcase[@cond.to_s.downcase]
        when Regexp       then mail.body.decoded.force_encoding("UTF-8").match(@cond)
        when Proc, Lambda then @cond[mail]
        else raise(ArgumentError, "unknown condition type #{@cond.class}")
      end
    end
  end
end
