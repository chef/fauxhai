# frozen_string_literal: true

require "timeout" unless defined?(Timeout)
require "socket" unless defined?(Socket)

module Fauxhai
  # Lightweight retry-with-backoff helper for external calls (HTTP, SSH).
  #
  # Usage:
  #   Fauxhai::Retrier.call(max_retries: 2, base_delay: 0.5) do
  #     Net::HTTP.get_response(uri)
  #   end
  #
  # Tuning parameters:
  #   max_retries  — number of retry attempts after the first failure (default: 2)
  #   base_delay   — initial delay in seconds between retries (default: 0.5)
  #   max_delay    — ceiling for exponential backoff in seconds (default: 5.0)
  #   timeout      — per-attempt timeout in seconds; nil = no timeout (default: 10)
  #   on           — array of exception classes to retry on (default: common network errors)
  #
  # Backoff formula: delay = min(base_delay * 2^attempt, max_delay)
  class Retrier
    NETWORK_ERRORS = [
      ::Timeout::Error,
      ::Errno::ECONNREFUSED,
      ::Errno::ECONNRESET,
      ::Errno::EHOSTUNREACH,
      ::Errno::ETIMEDOUT,
      ::SocketError,
      ::IOError
    ].freeze

    DEFAULT_OPTIONS = {
      max_retries: 2,
      base_delay: 0.5,
      max_delay: 5.0,
      timeout: 10,
      on: NETWORK_ERRORS
    }.freeze

    # Execute block with retry/backoff/timeout.
    #
    # @param opts [Hash] override any DEFAULT_OPTIONS key
    # @yield the operation to protect
    # @return whatever the block returns on success
    # @raise the last exception if all attempts fail
    def self.call(**opts, &)
      new(**opts).call(&)
    end

    def initialize(**opts)
      @config = DEFAULT_OPTIONS.merge(opts)
    end

    def call(&)
      attempts = 0
      begin
        if @config[:timeout]
          Timeout.timeout(@config[:timeout], &)
        else
          yield
        end
      rescue *@config[:on] => e
        attempts += 1
        raise if attempts > @config[:max_retries]

        delay = [@config[:base_delay] * (2**(attempts - 1)), @config[:max_delay]].min
        Fauxhai.logger&.warn { "retrier: attempt=#{attempts} error=#{e.class} delay=#{delay}s" }
        sleep(delay)
        retry
      end
    end
  end
end
