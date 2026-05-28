# frozen_string_literal: true

require "English"
require "spec_helper"
require "timeout"
require "stringio"
require "tmpdir"

describe Fauxhai::Resilience do
  let(:log_output) { StringIO.new }

  before do
    logger = Logger.new(log_output)
    logger.level = Logger::DEBUG
    Fauxhai.logger = logger
  end

  after do
    Fauxhai.logger = nil
  end

  describe ".with_retry" do
    it "returns the block result on success" do
      result = described_class.with_retry(max_retries: 0, timeout: nil) { 42 }
      expect(result).to eq(42)
    end

    it "does not retry non-retryable errors" do
      call_count = 0
      expect do
        described_class.with_retry(max_retries: 2, timeout: nil) do
          call_count += 1
          raise ArgumentError, "bad arg"
        end
      end.to raise_error(ArgumentError, "bad arg")
      expect(call_count).to eq(1)
    end

    it "retries retryable errors up to max_retries" do
      call_count = 0
      expect do
        described_class.with_retry(max_retries: 2, timeout: nil, base_delay: 0.001) do
          call_count += 1
          raise Errno::ECONNRESET
        end
      end.to raise_error(Errno::ECONNRESET)
      expect(call_count).to eq(3) # 1 initial + 2 retries
    end

    it "succeeds after transient failures" do
      call_count = 0
      result = described_class.with_retry(max_retries: 2, timeout: nil, base_delay: 0.001) do
        call_count += 1
        raise SocketError, "getaddrinfo failed" if call_count < 3

        "recovered"
      end
      expect(result).to eq("recovered")
      expect(call_count).to eq(3)
    end

    it "logs retry attempts" do
      call_count = 0
      described_class.with_retry(max_retries: 1, timeout: nil, base_delay: 0.001) do
        call_count += 1
        raise IOError, "stream closed" if call_count < 2

        "ok"
      end
      expect(log_output.string).to include("attempt 1/2 failed")
      expect(log_output.string).to include("IOError")
      expect(log_output.string).to include("retrying in")
    end

    it "logs exhaustion when all retries fail" do
      expect do
        described_class.with_retry(max_retries: 1, timeout: nil, base_delay: 0.001) do
          raise Errno::ECONNREFUSED
        end
      end.to raise_error(Errno::ECONNREFUSED)
      expect(log_output.string).to include("all 2 attempts exhausted")
    end

    it "raises Timeout::Error when block exceeds timeout" do
      expect do
        described_class.with_retry(max_retries: 0, timeout: 0.01) do
          sleep 1
        end
      end.to raise_error(Timeout::Error)
    end

    it "retries on Timeout::Error when retryable" do
      call_count = 0
      result = described_class.with_retry(max_retries: 1, timeout: 0.01, base_delay: 0.001) do
        call_count += 1
        if call_count < 2
          sleep 1 # will timeout
        else
          "fast"
        end
      end
      expect(result).to eq("fast")
      expect(call_count).to eq(2)
    end

    it "works with max_retries: 0 (no retries)" do
      call_count = 0
      expect do
        described_class.with_retry(max_retries: 0, timeout: nil) do
          call_count += 1
          raise Errno::ECONNRESET
        end
      end.to raise_error(Errno::ECONNRESET)
      expect(call_count).to eq(1)
    end

    it "accepts custom retryable error list" do
      call_count = 0
      expect do
        described_class.with_retry(
          max_retries: 1,
          timeout: nil,
          base_delay: 0.001,
          retryable: [RuntimeError]
        ) do
          call_count += 1
          raise "custom"
        end
      end.to raise_error(RuntimeError, "custom")
      expect(call_count).to eq(2)
    end
  end

  describe ".backoff_delay" do
    it "returns a positive delay" do
      delay = described_class.backoff_delay(1, 0.5)
      expect(delay).to be > 0
    end

    it "increases with attempt number" do
      # Use fixed seed for deterministic jitter
      srand(42)
      delay1 = described_class.backoff_delay(1, 0.5)
      srand(42)
      delay2 = described_class.backoff_delay(2, 0.5)
      # delay2 base (2^1 * 0.5 = 1.0) > delay1 base (2^0 * 0.5 = 0.5)
      # even with same jitter multiplier, delay2 should be higher
      expect(delay2).to be > delay1
    end

    it "stays within expected bounds" do
      # attempt 1, base 1.0: min = 1.0 * 0.5 = 0.5, max = 1.0 * 1.0 = 1.0
      100.times do
        delay = described_class.backoff_delay(1, 1.0)
        expect(delay).to be >= 0.5
        expect(delay).to be <= 1.0
      end
    end
  end

  describe "environment variable defaults" do
    after do
      # Clean up any ENV stubs
    end

    it "reads FAUXHAI_RETRY_MAX" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("FAUXHAI_RETRY_MAX", 2).and_return("5")
      expect(described_class.default_max_retries).to eq(5)
    end

    it "reads FAUXHAI_RETRY_BASE_DELAY" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("FAUXHAI_RETRY_BASE_DELAY", 0.5).and_return("1.5")
      expect(described_class.default_base_delay).to eq(1.5)
    end

    it "reads FAUXHAI_RETRY_TIMEOUT" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("FAUXHAI_RETRY_TIMEOUT", 30).and_return("60")
      expect(described_class.default_timeout).to eq(60)
    end

    it "uses defaults when ENV is not set" do
      expect(described_class.default_max_retries).to eq(2)
      expect(described_class.default_base_delay).to eq(0.5)
      expect(described_class.default_timeout).to eq(30)
    end
  end
end

describe "Resilience integration in Mocker" do
  let(:log_output) { StringIO.new }

  before do
    logger = Logger.new(log_output)
    logger.level = Logger::DEBUG
    Fauxhai.logger = logger
  end

  after do
    Fauxhai.logger = nil
  end

  it "retries on GitHub HTTP timeout" do
    require "net/http"
    call_count = 0
    allow(Net::HTTP).to receive(:get_response) do
      call_count += 1
      raise Timeout::Error, "execution expired" if call_count < 2

      instance_double(Net::HTTPResponse, code: "200", body: '{"platform": "test", "platform_version": "1.0"}')
    end

    mocker = Fauxhai::Mocker.new(platform: "nonexistent_for_test", version: "99.99")
    # Force github fetching path by stubbing File.exist? for the platform path
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(/nonexistent_for_test/).and_return(false)
    allow(Fauxhai::CacheManager).to receive(:write_json_file)

    # This should succeed after retry
    expect(mocker.data["platform"]).to eq("test")
    expect(log_output.string).to include("retrying in")
  end

  it "raises after exhausting retries on GitHub fetch" do
    require "net/http"
    allow(Net::HTTP).to receive(:get_response).and_raise(Timeout::Error, "execution expired")
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(/nonexistent_for_test/).and_return(false)
    allow(Fauxhai::CacheManager).to receive(:write_json_file)

    mocker = Fauxhai::Mocker.new(platform: "nonexistent_for_test", version: "99.99")
    expect { mocker.data }.to raise_error(Fauxhai::Exception::InvalidPlatform, /HTTP error/)
  end
end

describe "Resilience integration in CacheManager" do
  let(:log_output) { StringIO.new }
  let(:tmpfile) { File.join(Dir.tmpdir, "fauxhai_resilience_test_#{$PROCESS_ID}.json") }

  before do
    logger = Logger.new(log_output)
    logger.level = Logger::DEBUG
    Fauxhai.logger = logger
    File.write(tmpfile, '{"key": "value"}')
  end

  after do
    Fauxhai.logger = nil
    FileUtils.rm_f(tmpfile)
  end

  it "succeeds on normal read" do
    result = Fauxhai::CacheManager.read_json_file(tmpfile)
    expect(result).to eq({ "key" => "value" })
  end

  it "retries on transient IOError during read" do
    call_count = 0
    original_read = File.method(:read)
    allow(File).to receive(:read) do |path|
      if path == tmpfile
        call_count += 1
        raise IOError, "stream closed" if call_count < 2
      end
      original_read.call(path)
    end

    result = Fauxhai::CacheManager.read_json_file(tmpfile)
    expect(result).to eq({ "key" => "value" })
    expect(call_count).to eq(2)
  end
end
