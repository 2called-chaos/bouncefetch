# frozen_string_literal: true

module Bouncefetch
  class Application
    class Statistics
      attr_reader :storage

      def initialize
        @storage = {}
      end

      def add key, opts = {}, &block
        @storage[key.to_sym] = {
          display: true,
          value: 0,
          name: key.to_s.tr("_", " "),
          callback: block || ->(value, name, key, options){ "#{value} #{name}" },
        }.merge(opts)
      end

      def benchmark key, &block
        r0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
      ensure
        if @storage.key?(key.to_sym)
          @storage[key.to_sym][:value] += Process.clock_gettime(Process::CLOCK_MONOTONIC) - r0
        end
      end

      def any?
        @storage.any?
      end

      def render
        [].tap do |o|
          @storage.each do |key, options|
            if options[:display]
              o << options[:callback].call(options[:value], options[:name].to_s, key.to_s, options)
            end
          end
        end
      end

      # accessing or modifing a registered statistic key by calling it on the statistic handler
      #
      # ### Examples
      #     @stats.my_added_key    # returns the current value
      #     @stats.my_added_key 3  # will increase the value by 3 and return the result
      #     @stats.my_added_key +3 # the same
      #     @stats.my_added_key -3 # will decrease the value by 3 and return the result
      #
      # @param [Symbol] key statistic key name
      # @param [Integer] modify_value positive or negative number to in/decrease the value (if not passed or nil no changes will be made)
      # @return [Integer] current value (if changes are made this is the result of it)
      def method_missing key, *args, &block
        return unless @storage.key?(key.to_sym)

        @storage[key.to_sym][:value] += args[0] unless args[0].blank?
        @storage[key.to_sym][:value]
      end

      def respond_to_missing? meth, *args
        @storage.key?(key.to_sym)
      end
    end
  end
end
