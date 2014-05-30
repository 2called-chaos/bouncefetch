module Bouncefetch
  class Application
    class Rules < Configuration
      alias_method :type, :setup

      def crosschecks &block
        setup :crosschecks, &block
      end

      def rule condition = nil, &block
        @current_store[:rules] ||= []
        @current_store[:rules] << Rule.new(block || condition)
      end
    end
  end
end
