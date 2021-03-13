module Banana
  # This class provides a simple logger which maintains and displays the runtime of the logger instance.
  # It is intended to be used with the colorize gem but it brings its own colorization to eliminate a
  # dependency. You should initialize the logger as soon as possible to get an accurate runtime.
  #
  # @example
  #   logger = Banana::Logger.new
  #   logger.log "foo"
  #   logger.prefix = "[a] "
  #   logger.debug "bar"
  #   sleep 2
  #   logger.ensure_prefix("[b] ") { logger.warn "baz" }
  #   logger.log("rab!", :abort)
  #
  #   # Result:
  #   # [00:00:00.000 INFO]     foo
  #   # [00:00:00.000 DEBUG]    [a] bar
  #   # [00:00:02.001 WARN]     [b] baz
  #   # [00:00:02.001 ABORT]    [a] rab!
  #
  # @!attribute [r] startup
  #   @return [DateTime] Point of time where the logger was initiated.
  # @!attribute [r] channel
  #   @return [Object] The object where messages are getting send to.
  # @!attribute [r] method
  #   @return [Object] The method used to send messages to {#channel}.
  # @!attribute [r] logged
  #   @return [Integer] Amount of messages send to channel.
  #   @note This counter starts from 0 in every {#ensure_method} or {#log_with_print} block but gets
  #     added to the main counter after the call.
  # @!attribute timestr
  #   @return [Boolean] Set to false if the runtime indicator should not be printed (default: true).
  # @!attribute colorize
  #   @return [Boolean] Set to false if output should not be colored (default: true).
  # @!attribute prefix
  #   @return [String] Current prefix string for logged messages.
  class Logger
    attr_reader :startup, :channel, :method, :logged
    attr_accessor :colorize, :prefix

    # Foreground color values
    COLORMAP = {
      black: 30,
      red: 31,
      green: 32,
      yellow: 33,
      blue: 34,
      magenta: 35,
      cyan: 36,
      white: 37,
    }

    # Initializes a new logger instance. The internal runtime measurement starts here!
    #
    # There are 4 default log levels: info (yellow), warn & abort (red) and debug (blue).
    # All are enabled by default. You propably want to {#disable disable(:debug)}.
    #
    # @param scope Only for backward compatibility, not used
    # @todo add option hash
    def initialize scope = nil
      @startup = Time.now.utc
      @colorize = true
      @prefix = ""
      @enabled = true
      @timestr = true
      @channel = ::Kernel
      @method = :puts
      @logged = 0
      @levels = {
        info: { color: "yellow", enabled: true },
        warn: { color: "red", enabled: true },
        abort: { color: "red", enabled: true },
        debug: { color: "blue", enabled: true },
      }
    end

    # The default channel is `Kernel` which is Ruby's normal `puts`.
    # Attach it to a open file with write access and it will write into
    # the file. Ensure to close the file in your code.
    #
    # @param channel Object which responds to puts and print
    def attach channel
      @channel = channel
    end

    # Print raw message onto {#channel} using {#method}.
    #
    # @param [String] msg Message to send to {#channel}.
    # @param [Symbol] method Override {#method}.
    def raw msg, method = @method
      @channel.send(method, msg)
    end

    # Add additional log levels which are automatically enabled.
    # @param [Hash] levels Log levels in the format `{ debug: "red" }`
    def log_level levels = {}
      levels.each do |level, color|
        @levels[level.to_sym] ||= { enabled: true }
        @levels[level.to_sym][:color] = color
      end
    end

    # Calls the block with the given prefix and ensures that the prefix
    # will be the same as before.
    #
    # @param [String] prefix Prefix to use for the block
    # @param [Proc] block Block to call
    def ensure_prefix prefix, &block
      old_prefix, @prefix = @prefix, prefix
      block.call
    ensure
      @prefix = old_prefix
    end

    # Calls the block after changing the output method.
    # It also ensures to set back the method to what it was before.
    #
    # @param [Symbol] method Method to call on {#channel}
    def ensure_method method, &block
      old_method, old_logged = @method, @logged
      @method, @logged = method, 0
      block.call
    ensure
      @method = old_method
      @logged += old_logged
    end

    # Calls the block after changing the output method to `:print`.
    # It also ensures to set back the method to what it was before.
    #
    # @param [Boolean] clear If set to true and any message was printed inside the block
    #   a \n newline character will be printed.
    def log_with_print clear = true, &block
      ensure_method :print do
        begin
          block.call
        ensure
          raw(nil, :puts) if clear && @logged > 0
        end
      end
    end

    # Calls the block after disabling the runtime indicator.
    # It also ensures to set back the old setting after execution.
    def log_without_timestr &block
      timestr, @timestr = @timestr, false
      block.call
    ensure
      @timestr = timestr
    end

    # Calls the block after enabling the runtime indicator.
    # It also ensures to set back the old setting after execution.
    def log_with_timestr &block
      timestr, @timestr = @timestr, true
      block.call
    ensure
      @timestr = timestr
    end

    # @return [Boolean] returns true if the log level format :debug is enabled.
    def debug?
      enabled? :debug
    end

    # If a `level` is provided it will return true if this log level is enabled.
    # If no `level` is provided it will return true if the logger is enabled generally.
    #
    # @return [Boolean] returns true if the given log level is enabled
    def enabled? level = nil
      level.nil? ? @enabled : @levels[level.to_sym][:enabled]
    end

    # Same as {#enabled?} just negated.
    def disabled? level = nil
      !enabled?(level)
    end

    # Same as {#enable} just negated.
    #
    # @param [Symbol, String] level Loglevel to disable.
    def disable level = nil
      if level.nil?
        @enabled = false
      else
        @levels[level.to_sym][:enabled] = false
      end
    end

    # Enables the given `level` or the logger generally if no `level` is given.
    # If the logger is disabled no messages will be printed. If it is enabled
    # only messages for enabled log levels will be printed.
    #
    # @param [Symbol, String] level Loglevel to enable.
    def enable level = nil
      if level.nil?
        @enabled = true
      else
        @levels[level.to_sym][:enabled] = true
      end
    end

    # Colorizes the given string with the given color. It uses the build-in
    # colorization feature. You may want to use the colorize gem.
    #
    # @param [String] str The string to colorize
    # @param [Symbol, String] color The color to use (see {COLORMAP})
    # @raise [ArgumentError] if color does not exist in {COLORMAP}.
    def colorize str, color
      ccode = COLORMAP[color.to_sym] || raise(ArgumentError, "Unknown color #{color}!")
      "\e[#{ccode}m#{str}\e[0m"
    end

    def colorize?
      @colorize
    end

    # This method is the only method which sends the message `msg` to `@channel` via `@method`.
    # It also increments the message counter `@logged` by one.
    #
    # This method instantly returns nil if the logger or the given log level `type` is disabled.
    #
    # @param [String] msg The message to send to the channel
    # @param [Symbol] type The log level
    def log msg, type = :info
      return if !@enabled || !@levels[type][:enabled]
      if @levels[type.to_sym] || !@levels.key?(type.to_sym)
        time = Time.at(Time.now.utc - @startup).utc
        timestr = @timestr ? "[#{time.strftime("%H:%M:%S.%L")} #{type.to_s.upcase}]\t" : ""

        if @colorize
          msg = "#{colorize(timestr, @levels[type.to_sym][:color])}" <<
                "#{@prefix}" <<
                "#{colorize(msg, @levels[type.to_sym][:color])}"
        else
          msg = "#{timestr}#{@prefix}#{msg}"
        end
        @logged += 1
        @channel.send(@method, msg)
      end
    end
    alias_method :info, :log

    # Shortcut for {#log #log(msg, :debug)}
    #
    # @param [String] msg The message to send to {#log}.
    def debug msg
      log(msg, :debug)
    end

    # Shortcut for {#log #log(msg, :warn)} but sets channel method to "warn".
    #
    # @param [String] msg The message to send to {#log}.
    def warn msg
      ensure_method(:warn) { log(msg, :warn) }
    end

    # Shortcut for {#log #log(msg, :abort)} but sets channel method to "warn".
    #
    # @param [String] msg The message to send to {#log}.
    # @param [Integer] exit_code Exits with given code or does nothing when falsy.
    def abort msg, exit_code = false
      ensure_method(:warn) { log(msg, :abort) }
      exit(exit_code) if exit_code
    end
  end
end
