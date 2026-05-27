require "logger"

module Fauxhai
  autoload :Exception, "fauxhai/exception"
  autoload :Fetcher, "fauxhai/fetcher"
  autoload :Mocker, "fauxhai/mocker"
  autoload :VERSION, "fauxhai/version"
  autoload :VersionResolver, "fauxhai/version_resolver"

  # Optional logger for instrumentation. Disabled (nil) by default.
  # Set to any Logger-compatible object to enable structured log output
  # from Mocker and Fetcher.
  #
  # @example Enable logging
  #   Fauxhai.logger = Logger.new($stdout)
  #
  # @example Enable via environment variable
  #   FAUXHAI_LOG=1 bundle exec rspec
  class << self
    attr_writer :logger

    def logger
      @logger
    end
  end

  # Auto-enable logger if FAUXHAI_LOG environment variable is set.
  if ENV["FAUXHAI_LOG"]
    self.logger = Logger.new($stderr, progname: "fauxhai")
    self.logger.level = ENV.fetch("FAUXHAI_LOG_LEVEL", "DEBUG")
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
end
