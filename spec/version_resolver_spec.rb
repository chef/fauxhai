require "spec_helper"

describe Fauxhai::VersionResolver do
  let(:platform_path) { File.join(Fauxhai.root, "lib", "fauxhai", "platforms", platform) }

  describe ".resolve" do
    context "with an exact version match" do
      let(:platform) { "chefspec" }

      it "returns the exact version" do
        expect(described_class.resolve(platform_path, "0.6.1")).to eq "0.6.1"
      end
    end

    context "with a prefix match" do
      let(:platform) { "chefspec" }

      it "returns the best matching version" do
        expect(described_class.resolve(platform_path, "0.6")).to eq "0.6.1"
      end
    end

    context "with a non-matching prefix" do
      let(:platform) { "chefspec" }

      it "passes through the requested version" do
        expect(described_class.resolve(platform_path, "0.7")).to eq "0.7"
      end
    end

    context "with nil version" do
      let(:platform) { "chefspec" }

      it "returns the highest available version" do
        expect(described_class.resolve(platform_path, nil)).to eq "0.6.1"
      end
    end

    context "with blank version" do
      let(:platform) { "chefspec" }

      it "returns the highest available version" do
        expect(described_class.resolve(platform_path, "")).to eq "0.6.1"
      end
    end

    context "with a CentOS partial version" do
      let(:platform) { "centos" }

      it "returns the highest matching version for the prefix" do
        expect(described_class.resolve(platform_path, "7")).to eq "7.8.2003"
      end
    end

    context "with a Windows platform and no version" do
      let(:platform) { "windows" }

      it "returns the highest available version" do
        expect(described_class.resolve(platform_path, nil)).to eq "2022"
      end
    end

    context "with a Windows exact version" do
      let(:platform) { "windows" }

      it "returns the exact version" do
        expect(described_class.resolve(platform_path, "2012")).to eq "2012"
      end
    end

    context "with an invalid platform path" do
      let(:platform) { "nonexistent" }

      it "passes through the requested version" do
        expect(described_class.resolve(platform_path, "99")).to eq "99"
      end
    end

    context "with a CentOS exact version" do
      let(:platform) { "centos" }

      it "returns the exact version" do
        expect(described_class.resolve(platform_path, "6.10")).to eq "6.10"
      end
    end
  end
end
