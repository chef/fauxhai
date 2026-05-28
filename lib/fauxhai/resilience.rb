# frozen_string_literal: true

require "timeout" unless defined?(Timeout)
require "socket" unless defined?(SocketError)

module Fauxhai
  # Provides retry-with-backoff and timeout helpers for external call paths
  # (HTTP, SSH, disk I/O).
  #
  # == Usage
  #   Fauxhai::Resilience.with_retry(max_retries: 2, timeout: 10) do
  #     Net::HTTP.get_response(uri)
  #   end
  #
  # == Tuning parameters
  # All defaults can be overridden per-call or globally via environment:
  #
  # | Parameter       | Default | Env override               |
  # |-----------------|---------|----------------------------|
  # | max_retries     | 2       | FAUXHAI_RETRY_MAX          |
  # | base_delay      | 0.5s    | FAUXHAI_RETRY_BASE_DELAY   |
  # | timeout         | 30s     | FAUXHAI_RETRY_TIMEOUT      |
  # | retryable_errors| see below | —                        |
  #
  # == Backoff strategy
  # Exponential backoff with jitter:
  #   delay = base_delay * (2 ** attempt) * (0.5 + rand * 0.5)
  #
  # This prevents thundering-herd problems when multiple processes retry
  # against the same resource simultaneously.
  module Resilience
    # Default errors considered retryable (network + transient I/O).
    RETRYABLE_ERRORS = [
      Timeout::Error,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      Errno::EHOSTUNREACH,
      Errno::ENETUNREACH,
      IOError,
      SocketError
    ].freeze

    # Execute a block with timeout, retry, and exponential backoff.
    #
    # @param max_retries [Integer] maximum number of retries (0 = no retries)
    # @param base_delay [Float] base delay in seconds for backoff calculation
    # @param timeout [Integer, nil] per-attempt timeout in seconds (nil = no timeout)
    # @param retryable [Array<Class>] exception classes that trigger a retry
    # @yield the block to execute
    # @return whatever the block returns
    # @raise the last exception if all retries are exhausted
    def self.with_retry(
      max_retries: default_max_retries,
      base_delay: default_base_delay,
      timeout: default_timeout,
      retryable: RETRYABLE_ERRORS, &block
    )
      attempts = 0

      begin
        attempts += 1
        if timeout
          Timeout.timeout(timeout, &block)
        else
          yield
        end
      rescue *retryable => e
        if attempts <= max_retries
          delay = backoff_delay(attempts, base_delay)
          Fauxhai.logger.warn(
            "Resilience: attempt #{attempts}/#{max_retries + 1} failed " \
            "(#{e.class}: #{e.message}), retrying in #{delay.round(2)}s"
          )
          sleep(delay)
          retry
        else
          Fauxhai.logger.error(
            "Resilience: all #{attempts} attempts exhausted " \
            "(#{e.class}: #{e.message})"
          )
          raise
        end
      end
    end

    # Calculate backoff delay with jitter.
    # @param attempt [Integer] current attempt number (1-based)
    # @param base_delay [Float] base delay in seconds
    # @return [Float] delay in seconds
    def self.backoff_delay(attempt, base_delay)
      base_delay * (2**(attempt - 1)) * (0.5 + (rand * 0.5))
    end

    # Environment-overridable defaults.
    def self.default_max_retries
      Integer(ENV.fetch("FAUXHAI_RETRY_MAX", 2))
    end

    def self.default_base_delay
      Float(ENV.fetch("FAUXHAI_RETRY_BASE_DELAY", 0.5))
    end

    def self.default_timeout
      Integer(ENV.fetch("FAUXHAI_RETRY_TIMEOUT", 30))
    end
  end
end
