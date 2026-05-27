require "spec_helper"
require "net/http"
require "tmpdir"
require "fileutils"

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

    context "with a :path option pointing to a valid JSON file" do
      let(:tmpdir) { Dir.mktmpdir }
      let(:json_path) { File.join(tmpdir, "custom.json") }

      before do
        File.write(json_path, { "platform" => "custom", "hostname" => "pathhost" }.to_json)
      end

      after { FileUtils.remove_entry(tmpdir) }

      it "loads data from the specified path" do
        mocker = described_class.new(path: json_path, github_fetching: false)
        expect(mocker.data["hostname"]).to eq("pathhost")
      end
    end

    context "with a :path option pointing to a nonexistent file" do
      it "raises InvalidPlatform" do
        expect {
          described_class.new(path: "/nonexistent/fake.json", github_fetching: false).data
        }.to raise_error(Fauxhai::Exception::InvalidPlatform, /does not exist/)
      end
    end

    context "GitHub fetching succeeds with 200" do
      let(:tmpdir) { Dir.mktmpdir }
      let(:response_body) { { "platform" => "newplat", "hostname" => "ghhost" }.to_json }
      let(:response) { instance_double(Net::HTTPOK, code: "200", body: response_body) }

      before do
        allow(Fauxhai).to receive(:root).and_return(tmpdir)
        allow(Net::HTTP).to receive(:get_response).and_return(response)
      end

      after { FileUtils.remove_entry(tmpdir) }

      it "fetches from GitHub and caches locally" do
        mocker = described_class.new(platform: "newplat", version: "1.0", github_fetching: true)
        expect(mocker.data["hostname"]).to eq("ghhost")

        cached_path = File.join(tmpdir, "lib", "fauxhai", "platforms", "newplat", "1.0.json")
        expect(File.exist?(cached_path)).to be true
      end
    end

    context "GitHub fetching succeeds but write fails with EACCES" do
      let(:tmpdir) { Dir.mktmpdir }
      let(:response_body) { { "platform" => "noperm", "hostname" => "nopermhost" }.to_json }
      let(:response) { instance_double(Net::HTTPOK, code: "200", body: response_body) }

      before do
        allow(Fauxhai).to receive(:root).and_return(tmpdir)
        allow(Net::HTTP).to receive(:get_response).and_return(response)
        allow(File).to receive(:open).and_call_original
        allow(File).to receive(:open).with(anything, "w").and_raise(Errno::EACCES)
      end

      after { FileUtils.remove_entry(tmpdir) }

      it "still returns data despite write failure" do
        mocker = described_class.new(platform: "noperm", version: "1.0", github_fetching: true)
        expect(mocker.data["hostname"]).to eq("nopermhost")
      end
    end

    context "GitHub fetching raises a network error" do
      before do
        allow(Net::HTTP).to receive(:get_response).and_raise(SocketError, "getaddrinfo failure")
      end

      it "raises InvalidPlatform with HTTP error message" do
        expect {
          described_class.new(platform: "neterr", version: "1.0", github_fetching: true).data
        }.to raise_error(Fauxhai::Exception::InvalidPlatform, /HTTP error/)
      end
    end

    context "with github_fetching disabled and unknown platform" do
      it "raises InvalidPlatform" do
        expect {
          described_class.new(platform: "doesntexist", version: "1", github_fetching: false).data
        }.to raise_error(Fauxhai::Exception::InvalidPlatform, /Github fetching is disabled/)
      end
    end

    context "with deprecated platform data" do
      let(:tmpdir) { Dir.mktmpdir }
      let(:json_path) { File.join(tmpdir, "deprecated.json") }

      before do
        File.write(json_path, { "platform" => "oldos", "platform_version" => "1.0", "deprecated" => true }.to_json)
      end

      after { FileUtils.remove_entry(tmpdir) }

      it "logs a deprecation warning" do
        expect(Fauxhai.logger).to receive(:warn).with(/deprecated/)
        described_class.new(path: json_path, github_fetching: false).data
      end
    end

    context "with a block" do
      it "yields data for override" do
        yielded = nil
        described_class.new(platform: "chefspec", version: "0.6.1", github_fetching: false) do |data|
          yielded = data
          data["custom_key"] = "custom_value"
        end
        expect(yielded).to be_a(Hash)
        expect(yielded["custom_key"]).to eq("custom_value")
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

  describe "#platform_path (memoization)" do
    it "returns the same object on repeated calls" do
      mocker = described_class.new(platform: "ubuntu", version: "20.04", github_fetching: false)
      path1 = mocker.send(:platform_path)
      path2 = mocker.send(:platform_path)
      expect(path1).to equal(path2) # same object identity, not just equal value
    end

    it "calls File.join only once across multiple accesses" do
      mocker = described_class.new(platform: "ubuntu", version: "20.04", github_fetching: false)
      allow(File).to receive(:join).and_call_original
      mocker.send(:platform_path)
      mocker.send(:platform_path)
      mocker.send(:platform_path)
      # File.join is called during memoization setup; after first call,
      # subsequent calls should return the cached value without File.join
      expect(File).to have_received(:join).with(Fauxhai.root, "lib", "fauxhai", "platforms", "ubuntu").once
    end
  end

  describe "#load_platform_data (extracted from lambda)" do
    it "is a private method that returns parsed JSON data" do
      mocker = described_class.new(platform: "chefspec", version: "0.6.1", github_fetching: false)
      result = mocker.send(:load_platform_data)
      expect(result).to be_a(Hash)
      expect(result["hostname"]).to eq("chefspec")
    end

    it "returns the same data as #data" do
      mocker = described_class.new(platform: "ubuntu", version: "20.04", github_fetching: false)
      expect(mocker.send(:load_platform_data)).to eq(mocker.data)
    end

    it "does not allocate a Proc/lambda for data loading" do
      mocker = described_class.new(platform: "chefspec", version: "0.6.1", github_fetching: false)
      before_count = ObjectSpace.count_objects[:T_DATA]
      mocker.data
      after_count = ObjectSpace.count_objects[:T_DATA]
      expect(after_count).to be <= before_count + 1
    end
  end

  describe "input validation (security)" do
    context "with path traversal in platform" do
      it "raises InvalidPlatform for '../etc'" do
        expect {
          described_class.new(platform: "../etc", version: "1", github_fetching: false).data
        }.to raise_error(Fauxhai::Exception::InvalidPlatform, /Invalid platform/)
      end
    end

    context "with URL injection in platform" do
      it "raises InvalidPlatform for 'foo%2F..%2Fbar'" do
        expect {
          described_class.new(platform: "foo%2F..%2Fbar", version: "1", github_fetching: false).data
        }.to raise_error(Fauxhai::Exception::InvalidPlatform, /Invalid platform/)
      end
    end

    context "with path traversal in version" do
      it "raises InvalidPlatform for '../../etc/passwd'" do
        expect {
          described_class.new(platform: "ubuntu", version: "../../etc/passwd", github_fetching: false).data
        }.to raise_error(Fauxhai::Exception::InvalidPlatform, /Invalid version/)
      end
    end

    context "with slash in version" do
      it "raises InvalidPlatform for versions containing '/'" do
        expect {
          described_class.new(platform: "ubuntu", version: "20/04", github_fetching: false).data
        }.to raise_error(Fauxhai::Exception::InvalidPlatform, /Invalid version/)
      end
    end

    context "with valid platform and version" do
      it "allows alphanumeric with dots (e.g. ubuntu 20.04)" do
        expect {
          described_class.new(platform: "ubuntu", version: "20.04", github_fetching: false).data
        }.not_to raise_error
      end

      it "allows dashes (e.g. centos-stream)" do
        expect {
          described_class.new(platform: "centos-stream", version: "8", github_fetching: false).data
        }.not_to raise_error
      end

      it "allows underscores (e.g. mac_os_x)" do
        expect {
          described_class.new(platform: "mac_os_x", version: "10.15", github_fetching: false).data
        }.not_to raise_error
      end

      it "allows ARCH-style versions (e.g. 4.10.13-1-ARCH)" do
        expect {
          described_class.new(platform: "arch", version: "4.10.13-1-ARCH", github_fetching: false).data
        }.not_to raise_error
      end
    end
  end
end
