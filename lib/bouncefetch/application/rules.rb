# frozen_string_literal: true

module Bouncefetch
  class Application
    class Rules < Configuration
      alias_method :type, :setup

      def crosschecks &block
        setup(:crosschecks, &block)
      end

      def rule *args, **kw, &block
        source_location = begin
          loc = caller(1..1).first.split(":in").first&.split(":")
          [loc[..-2].join(":"), loc[-1].to_i] if loc
        end

        @current_store[:rules] ||= []
        @current_store[:rules].unshift Rule.new(*args, **kw, source_location: source_location, &block)
      end
    end
  end
end
