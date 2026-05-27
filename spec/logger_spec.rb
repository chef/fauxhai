require "spec_helper"
require "logger"
require "stringio"
require "tmpdir"
require "fileutils"

describe "Fauxhai.logger" do
  after do
    # Reset logger between tests so each test gets a clean state
    Fauxhai.logger = nil
  end

  describe "default configuration" do
    it "returns a Logger instance" do
      expect(Fauxhai.logger).to be_a(Logger)
    end

    it "defaults to WARN level" do
      expect(Fauxhai.logger.level).to eq(Logger::WARN)
    end

    it "sets progname to 'fauxhai'" do
      expect(Fauxhai.logger.progname).to eq("fauxhai")
    end

    it "formats output as [fauxhai] SEVERITY: message" do
      output = StringIO.new
      Fauxhai.logger = Logger.new(output, level: :warn)
      Fauxhai.logger.progname = "fauxhai"
      Fauxhai.logger.formatter = proc { |severity, _time, progname, msg|
        "[#{progname}] #{severity}: #{msg}\n"
      }
      Fauxhai.logger.warn("test message")
      expect(output.string).to include("[fauxhai] WARN: test message")
    end
  end

  describe ".logger=" do
    it "allows replacing the logger" do
      custom = Logger.new(StringIO.new)
      Fauxhai.logger = custom
      expect(Fauxhai.logger).to equal(custom)
    end

    it "can be reset to nil to get a new default logger" do
      custom = Logger.new(StringIO.new)
      Fauxhai.logger = custom
      Fauxhai.logger = nil
      expect(Fauxhai.logger).to be_a(Logger)
      expect(Fauxhai.logger).not_to equal(custom)
    end
  end

  describe "FAUXHAI_LOG_LEVEL environment variable" do
    %w[DEBUG INFO WARN ERROR FATAL].each do |level|
      it "respects FAUXHAI_LOG_LEVEL=#{level}" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("FAUXHAI_LOG_LEVEL").and_return(level)
        Fauxhai.logger = nil # force re-creation
        expect(Fauxhai.logger.level).to eq(Logger.const_get(level))
      end
    end

    it "defaults to WARN for unknown values" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("FAUXHAI_LOG_LEVEL").and_return("INVALID")
      Fauxhai.logger = nil
      expect(Fauxhai.logger.level).to eq(Logger::WARN)
    end
  end

  describe "integration with Mocker" do
    it "emits warn for deprecated platform data" do
      tmpdir = Dir.mktmpdir
      json_path = File.join(tmpdir, "deprecated.json")
      File.write(json_path, { "platform" => "oldos", "platform_version" => "1.0", "deprecated" => true }.to_json)

      expect(Fauxhai.logger).to receive(:warn).with(/deprecated/)
      Fauxhai::Mocker.new(path: json_path, github_fetching: false).data
    ensure
      FileUtils.remove_entry(tmpdir) if tmpdir
    end

    it "emits debug for local file loading when level is DEBUG" do
      output = StringIO.new
      Fauxhai.logger = Logger.new(output, level: :debug)
      Fauxhai.logger.progname = "fauxhai"

      Fauxhai::Mocker.new(platform: "chefspec", version: "0.6.1", github_fetching: false).data
      expect(output.string).to include("Loading platform data from local file")
    end

    it "does not emit debug messages at WARN level" do
      output = StringIO.new
      Fauxhai.logger = Logger.new(output, level: :warn)

      Fauxhai::Mocker.new(platform: "chefspec", version: "0.6.1", github_fetching: false).data
      expect(output.string).to be_empty
    end
  end
end
