# frozen_string_literal: true

require "spec_helper"
require "stringio"

describe "Fauxhai.strict_mode" do
  after do
    # Reset strict_mode between tests
    Fauxhai.strict_mode = nil
  end

  describe "default configuration" do
    it "defaults to false when ENV is not set" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("FAUXHAI_STRICT_MODE").and_return(nil)
      Fauxhai.strict_mode = nil
      expect(Fauxhai.strict_mode).to eq(false)
    end

    it "returns false when ENV is empty string" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("FAUXHAI_STRICT_MODE").and_return("")
      Fauxhai.strict_mode = nil
      expect(Fauxhai.strict_mode).to eq(false)
    end
  end

  describe ".strict_mode=" do
    it "allows enabling strict mode" do
      Fauxhai.strict_mode = true
      expect(Fauxhai.strict_mode).to eq(true)
    end

    it "allows disabling strict mode" do
      Fauxhai.strict_mode = true
      Fauxhai.strict_mode = false
      expect(Fauxhai.strict_mode).to eq(false)
    end

    it "can be reset to nil to fall back to ENV" do
      Fauxhai.strict_mode = true
      Fauxhai.strict_mode = nil
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("FAUXHAI_STRICT_MODE").and_return(nil)
      expect(Fauxhai.strict_mode).to eq(false)
    end
  end

  describe "FAUXHAI_STRICT_MODE environment variable" do
    %w[1 true yes on].each do |val|
      it "enables strict mode when ENV is '#{val}'" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("FAUXHAI_STRICT_MODE").and_return(val)
        Fauxhai.strict_mode = nil
        expect(Fauxhai.strict_mode).to eq(true)
      end
    end

    %w[TRUE Yes ON].each do |val|
      it "is case-insensitive: ENV '#{val}' enables strict mode" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("FAUXHAI_STRICT_MODE").and_return(val)
        Fauxhai.strict_mode = nil
        expect(Fauxhai.strict_mode).to eq(true)
      end
    end

    %w[0 false no off anything].each do |val|
      it "does not enable strict mode when ENV is '#{val}'" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("FAUXHAI_STRICT_MODE").and_return(val)
        Fauxhai.strict_mode = nil
        expect(Fauxhai.strict_mode).to eq(false)
      end
    end
  end

  describe "setter takes precedence over ENV" do
    it "uses setter value even when ENV is set" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("FAUXHAI_STRICT_MODE").and_return("1")
      Fauxhai.strict_mode = false
      expect(Fauxhai.strict_mode).to eq(false)
    end

    it "uses setter value true even when ENV is unset" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("FAUXHAI_STRICT_MODE").and_return(nil)
      Fauxhai.strict_mode = true
      expect(Fauxhai.strict_mode).to eq(true)
    end
  end
end

describe "strict_mode behavior in Mocker" do
  let(:log_output) { StringIO.new }

  before do
    logger = Logger.new(log_output)
    logger.level = Logger::DEBUG
    Fauxhai.logger = logger
  end

  after do
    Fauxhai.strict_mode = nil
    Fauxhai.logger = nil
  end

  describe "platform fallback" do
    context "when strict_mode is OFF (default)" do
      before { Fauxhai.strict_mode = false }

      it "falls back to 'chefspec' with a warning when no platform is specified" do
        mocker = Fauxhai::Mocker.new
        expect(mocker.data).to be_a(Hash)
        expect(log_output.string).to include("strict_mode=false")
        expect(log_output.string).to include("falling back to 'chefspec' platform")
      end

      it "does not raise when no platform is specified" do
        expect { Fauxhai::Mocker.new.data }.not_to raise_error
      end
    end

    context "when strict_mode is ON" do
      before { Fauxhai.strict_mode = true }

      it "raises InvalidPlatform when no platform is specified" do
        expect { Fauxhai::Mocker.new.data }.to raise_error(
          Fauxhai::Exception::InvalidPlatform,
          /you must specify a 'platform'/
        )
      end

      it "logs strict_mode=true telemetry" do
        begin
          Fauxhai::Mocker.new.data
        rescue Fauxhai::Exception::InvalidPlatform
          # expected
        end
        expect(log_output.string).to include("strict_mode=true")
        expect(log_output.string).to include("raising on missing platform")
      end
    end

    context "when platform IS specified" do
      it "behaves the same regardless of strict_mode" do
        Fauxhai.strict_mode = true
        mocker = Fauxhai::Mocker.new(platform: "ubuntu", version: "22.04")
        expect(mocker.data).to be_a(Hash)
        expect(mocker.data["platform"]).to eq("ubuntu")
      end
    end
  end

  describe "deprecated platform data" do
    let(:deprecated_json) do
      JSON.generate({
                      "platform" => "testplatform",
                      "platform_version" => "1.0",
                      "deprecated" => true
                    })
    end

    let(:non_deprecated_json) do
      JSON.generate({
                      "platform" => "testplatform",
                      "platform_version" => "2.0"
                    })
    end

    context "when strict_mode is OFF" do
      before { Fauxhai.strict_mode = false }

      it "warns but returns data for deprecated platforms" do
        mocker = Fauxhai::Mocker.new(platform: "ubuntu", version: "22.04")
        # Use send to test the private method directly
        result = mocker.send(:parse_and_validate, deprecated_json)
        expect(result["deprecated"]).to eq(true)
        expect(log_output.string).to include("strict_mode=false")
        expect(log_output.string).to include("deprecated")
      end

      it "returns data without warnings for non-deprecated platforms" do
        mocker = Fauxhai::Mocker.new(platform: "ubuntu", version: "22.04")
        result = mocker.send(:parse_and_validate, non_deprecated_json)
        expect(result["platform"]).to eq("testplatform")
        expect(log_output.string).not_to include("deprecated")
      end
    end

    context "when strict_mode is ON" do
      before { Fauxhai.strict_mode = true }

      it "raises InvalidPlatform for deprecated platforms" do
        mocker = Fauxhai::Mocker.new(platform: "ubuntu", version: "22.04")
        expect do
          mocker.send(:parse_and_validate, deprecated_json)
        end.to raise_error(
          Fauxhai::Exception::InvalidPlatform,
          /deprecated/
        )
      end

      it "logs strict_mode=true telemetry for deprecated data" do
        mocker = Fauxhai::Mocker.new(platform: "ubuntu", version: "22.04")
        begin
          mocker.send(:parse_and_validate, deprecated_json)
        rescue Fauxhai::Exception::InvalidPlatform
          # expected
        end
        expect(log_output.string).to include("strict_mode=true")
        expect(log_output.string).to include("raising on deprecated")
      end

      it "returns data for non-deprecated platforms" do
        mocker = Fauxhai::Mocker.new(platform: "ubuntu", version: "22.04")
        result = mocker.send(:parse_and_validate, non_deprecated_json)
        expect(result["platform"]).to eq("testplatform")
      end
    end
  end

  describe "rollback" do
    it "can be toggled off after being enabled" do
      Fauxhai.strict_mode = true
      expect { Fauxhai::Mocker.new.data }.to raise_error(Fauxhai::Exception::InvalidPlatform)

      # Rollback: disable strict mode
      Fauxhai.strict_mode = false
      expect { Fauxhai::Mocker.new.data }.not_to raise_error
    end

    it "can be toggled off mid-session without restarting" do
      Fauxhai.strict_mode = true
      Fauxhai.strict_mode = false
      mocker = Fauxhai::Mocker.new
      expect(mocker.data).to be_a(Hash)
    end
  end
end
