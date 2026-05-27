# frozen_string_literal: true

require "spec_helper"

RSpec.describe Fauxhai::Retrier do
  # Suppress sleep in tests so they run fast.
  before { allow_any_instance_of(described_class).to receive(:sleep) }

  describe ".call" do
    it "returns the block value on first success" do
      result = described_class.call(max_retries: 2) { "ok" }
      expect(result).to eq "ok"
    end

    it "retries on a matching error and succeeds" do
      attempts = 0
      result = described_class.call(max_retries: 2, base_delay: 0, on: [Errno::ECONNREFUSED]) do
        attempts += 1
        raise Errno::ECONNREFUSED if attempts < 2

        "recovered"
      end
      expect(result).to eq "recovered"
      expect(attempts).to eq 2
    end

    it "raises after exhausting all retries" do
      expect {
        described_class.call(max_retries: 1, base_delay: 0, on: [Errno::ECONNRESET]) do
          raise Errno::ECONNRESET
        end
      }.to raise_error(Errno::ECONNRESET)
    end

    it "does not retry on non-matching errors" do
      expect {
        described_class.call(max_retries: 3, on: [Errno::ECONNREFUSED]) do
          raise ArgumentError, "bad arg"
        end
      }.to raise_error(ArgumentError, "bad arg")
    end

    it "applies exponential backoff delays" do
      retrier = described_class.new(max_retries: 3, base_delay: 1.0, max_delay: 10.0, timeout: nil, on: [RuntimeError])
      delays = []
      allow(retrier).to receive(:sleep) { |d| delays << d }

      attempts = 0
      retrier.call do
        attempts += 1
        raise RuntimeError if attempts <= 3

        "done"
      end

      # base_delay * 2^0 = 1.0, base_delay * 2^1 = 2.0, base_delay * 2^2 = 4.0
      expect(delays).to eq [1.0, 2.0, 4.0]
    end

    it "caps delay at max_delay" do
      retrier = described_class.new(max_retries: 3, base_delay: 4.0, max_delay: 5.0, timeout: nil, on: [RuntimeError])
      delays = []
      allow(retrier).to receive(:sleep) { |d| delays << d }

      attempts = 0
      retrier.call do
        attempts += 1
        raise RuntimeError if attempts <= 2

        "done"
      end

      # base_delay * 2^0 = 4.0, base_delay * 2^1 = 8.0 → capped to 5.0
      expect(delays).to eq [4.0, 5.0]
    end

    it "raises Timeout::Error when block exceeds timeout" do
      expect {
        described_class.call(max_retries: 0, timeout: 0.01, on: []) do
          sleep 1
        end
      }.to raise_error(Timeout::Error)
    end

    it "retries on timeout when Timeout::Error is in the on list" do
      attempts = 0
      result = described_class.call(max_retries: 1, timeout: 0.01, base_delay: 0, on: [Timeout::Error]) do
        attempts += 1
        if attempts < 2
          sleep 1 # triggers timeout
        else
          "ok"
        end
      end
      expect(result).to eq "ok"
      expect(attempts).to eq 2
    end

    it "skips timeout when timeout is nil" do
      result = described_class.call(max_retries: 0, timeout: nil) { "no timeout" }
      expect(result).to eq "no timeout"
    end

    it "logs warnings on retry when logger is set" do
      log_output = StringIO.new
      logger = Logger.new(log_output, progname: "fauxhai")
      original_logger = Fauxhai.logger
      Fauxhai.logger = logger

      attempts = 0
      described_class.call(max_retries: 1, base_delay: 0, on: [Errno::ECONNREFUSED]) do
        attempts += 1
        raise Errno::ECONNREFUSED if attempts < 2

        "ok"
      end

      expect(log_output.string).to include("retrier:")
      expect(log_output.string).to include("attempt=1")
      expect(log_output.string).to include("Errno::ECONNREFUSED")
    ensure
      Fauxhai.logger = original_logger
    end

    it "does not log when logger is nil" do
      original_logger = Fauxhai.logger
      Fauxhai.logger = nil

      attempts = 0
      expect {
        described_class.call(max_retries: 1, base_delay: 0, on: [Errno::ECONNREFUSED]) do
          attempts += 1
          raise Errno::ECONNREFUSED if attempts < 2

          "ok"
        end
      }.not_to raise_error
    ensure
      Fauxhai.logger = original_logger
    end
  end

  describe "default configuration" do
    it "has sensible defaults" do
      retrier = described_class.new
      config = retrier.instance_variable_get(:@config)

      expect(config[:max_retries]).to eq 2
      expect(config[:base_delay]).to eq 0.5
      expect(config[:max_delay]).to eq 5.0
      expect(config[:timeout]).to eq 10
      expect(config[:on]).to include(Timeout::Error)
      expect(config[:on]).to include(Errno::ECONNREFUSED)
    end
  end
end
