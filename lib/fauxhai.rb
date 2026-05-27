# frozen_string_literal: true

require "logger"

module Fauxhai
  autoload :CacheManager, "fauxhai/cache_manager"
  autoload :Exception, "fauxhai/exception"
  autoload :Fetcher, "fauxhai/fetcher"
  autoload :Mocker, "fauxhai/mocker"
  autoload :VERSION, "fauxhai/version"

  # Returns the shared Logger instance for Fauxhai.
  #
  # Defaults to STDERR at WARN level. Control via:
  #   ENV["FAUXHAI_LOG_LEVEL"] — DEBUG, INFO, WARN (default), ERROR, FATAL
  #   Fauxhai.logger = Logger.new($stdout, level: :debug)
  #
  # All lib/fauxhai/ files use this logger for consistent output.
  def self.logger
    @logger ||= begin
      l = Logger.new($stderr)
      l.progname = "fauxhai"
      l.level = log_level_from_env
      l.formatter = proc { |severity, _time, progname, msg|
        "[#{progname}] #{severity}: #{msg}\n"
      }
      l
    end
  end

  # Override the default logger (e.g. in tests or when embedding Fauxhai).
  def self.logger=(new_logger)
    @logger = new_logger
  end

  # Returns whether strict mode is enabled.
  #
  # Strict mode changes two higher-risk behaviors:
  #   1. Missing platform: raises InvalidPlatform instead of falling back
  #      to "chefspec" with a warning.
  #   2. Deprecated platform data: raises InvalidPlatform instead of
  #      logging a warning and returning the data.
  #
  # Toggle via:
  #   Fauxhai.strict_mode = true
  #   ENV["FAUXHAI_STRICT_MODE"] = "1"  (or "true", "yes", "on")
  #
  # Default: false (backward-compatible).
  def self.strict_mode
    return @strict_mode unless @strict_mode.nil?
    %w[1 true yes on].include?(ENV["FAUXHAI_STRICT_MODE"].to_s.downcase)
  end

  # Enable or disable strict mode.
  def self.strict_mode=(value)
    @strict_mode = value
  end

  def self.root
    @@root ||= File.expand_path("../../", __FILE__)
  end

  def self.mock(*args, &block)
    Fauxhai::Mocker.new(*args, &block)
  end

  def self.fetch(*args, &block)
    Fauxhai::Fetcher.new(*args, &block)
  end

  # Map FAUXHAI_LOG_LEVEL env var to Logger constant.
  def self.log_level_from_env
    case ENV["FAUXHAI_LOG_LEVEL"].to_s.upcase
    when "DEBUG" then Logger::DEBUG
    when "INFO"  then Logger::INFO
    when "ERROR" then Logger::ERROR
    when "FATAL" then Logger::FATAL
    else Logger::WARN
    end
  end
  private_class_method :log_level_from_env
end
