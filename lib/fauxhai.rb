# frozen_string_literal: true

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
    attr_accessor :logger
  end

  # Auto-enable logger if FAUXHAI_LOG environment variable is set.
  if ENV["FAUXHAI_LOG"]
    self.logger = Logger.new($stderr, progname: "fauxhai")
    logger.level = ENV.fetch("FAUXHAI_LOG_LEVEL", "DEBUG")
  end

  def self.root
    # rubocop:disable Style/ClassVars -- @@root is the public API used by Mocker, Fetcher, and downstream consumers. Changing to a class instance var would break subclass inheritance semantics.
    @@root ||= File.expand_path("..", __dir__)
    # rubocop:enable Style/ClassVars
  end

  def self.mock(...)
    Fauxhai::Mocker.new(...)
  end

  def self.fetch(...)
    Fauxhai::Fetcher.new(...)
  end
end
