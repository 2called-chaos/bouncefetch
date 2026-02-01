# frozen_string_literal: true

module Bouncefetch
  class Application
    class Rules < Configuration
      alias_method :type, :setup

      def crosschecks &block
        setup(:crosschecks, &block)
      end

      def rule *args, **kw, &block
        @current_store[:rules] ||= []
        @current_store[:rules].unshift Rule.new(*args, **kw, &block)
      end
    end
  end
end
