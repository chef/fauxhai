require "spec_helper"
require "net/http"

describe Fauxhai::Mocker do
  describe "#data" do
    let(:options) { {} }
    subject { described_class.new({ github_fetching: false }.merge(options)).data }

    context "with a platform and version" do
      let(:options) { { platform: "chefspec", version: "0.6.1" } }
      its(["hostname"]) { is_expected.to eq "chefspec" }
    end

    context "with a Windows platform and version" do
      let(:options) { { platform: "windows", version: "10" } }
      its(["hostname"]) { is_expected.to eq "Fauxhai" }
    end

    context "GitHub fetching fails" do
      let(:options) {
        {
          github_fetching: true,
          platform: "doesntexist",
          version: "1"
        }
      }

      before do
        allow(Net::HTTP)
          .to receive(:get_response)
          .and_return(Net::HTTPNotFound.new('1.1', '404', 'Not Found'))
      end

      it 'yields a InvalidPlatform exception' do
        expect { subject }.to raise_error(Fauxhai::Exception::InvalidPlatform, /http error code 404/)
      end
    end
  end

  describe "#version" do
    let(:options) { {} }
    subject { described_class.new({ github_fetching: false }.merge(options)).send(:version) }

    context "with a platform and version" do
      let(:options) { { platform: "chefspec", version: "0.6.1" } }
      it { is_expected.to eq "0.6.1" }
    end

    context "with a platform and no version" do
      let(:options) { { platform: "chefspec" } }
      it { is_expected.to eq "0.6.1" }
    end

    context "with a platform and a blank version" do
      let(:options) { { platform: "chefspec", version: "" } }
      it { is_expected.to eq "0.6.1" }
    end

    context "with a platform and a partial version" do
      let(:options) { { platform: "chefspec", version: "0.6" } }
      it { is_expected.to eq "0.6.1" }
    end

    context "with a platform and a non-matching partial version" do
      let(:options) { { platform: "chefspec", version: "0.7" } }
      it { is_expected.to eq "0.7" }
    end

    context "with a Windows platform and no version" do
      let(:options) { { platform: "windows" } }
      it { is_expected.to eq "2022" }
    end

    context "with a Windows platform and an exact partial version" do
      let(:options) { { platform: "windows", version: "2012" } }
      it { is_expected.to eq "2012" }
    end

    context "with a CentOS platform and a partial version" do
      let(:options) { { platform: "centos", version: "6" } }
      it { is_expected.to eq "6.10" }
    end

    context "with a platform and an invalid version" do
      let(:options) { { platform: "chefspec", version: "99" } }
      it { is_expected.to eq "99" }
    end

    context "with an invalid platform and an invalid version" do
      let(:options) { { platform: "notthere", version: "99" } }
      it { is_expected.to eq "99" }
    end
  end

  describe ".json_cache" do
    before { described_class.clear_cache! }

    it "caches the raw JSON string after first read" do
      described_class.new(platform: "chefspec", version: "0.6.1", github_fetching: false).data
      expect(described_class.json_cache.size).to eq 1
      expect(described_class.json_cache.values.first).to be_a(String)
    end

    it "returns independent data hashes from the same cache entry" do
      a = described_class.new(platform: "chefspec", version: "0.6.1", github_fetching: false).data
      b = described_class.new(platform: "chefspec", version: "0.6.1", github_fetching: false).data
      a["hostname"] = "mutated"
      expect(b["hostname"]).to eq "chefspec"
    end

    it "is clearable" do
      described_class.new(platform: "chefspec", version: "0.6.1", github_fetching: false).data
      expect(described_class.json_cache).not_to be_empty
      described_class.clear_cache!
      expect(described_class.json_cache).to be_empty
    end
  end

  describe "instrumentation logging" do
    let(:log_output) { StringIO.new }
    let(:logger) { Logger.new(log_output, progname: "fauxhai") }

    before do
      Fauxhai.logger = logger
      described_class.clear_cache!
    end

    after do
      Fauxhai.logger = nil
    end

    it "logs platform_load with source and elapsed_ms on data access" do
      described_class.new(platform: "chefspec", version: "0.6.1", github_fetching: false).data
      output = log_output.string
      expect(output).to include("platform_load:")
      expect(output).to include("platform=chefspec")
      expect(output).to include("source=disk")
      expect(output).to include("elapsed_ms=")
    end

    it "logs source=cache on repeated access" do
      described_class.new(platform: "chefspec", version: "0.6.1", github_fetching: false).data
      log_output.truncate(0)
      log_output.rewind
      described_class.new(platform: "chefspec", version: "0.6.1", github_fetching: false).data
      expect(log_output.string).to include("source=cache")
    end

    it "does not log when logger is nil" do
      Fauxhai.logger = nil
      expect {
        described_class.new(platform: "chefspec", version: "0.6.1", github_fetching: false).data
      }.not_to raise_error
    end
  end
end
