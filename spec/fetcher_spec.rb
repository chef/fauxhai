require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Fauxhai::Fetcher do
  let(:ohai_data) { { "platform" => "ubuntu", "platform_version" => "20.04", "hostname" => "testhost" } }
  let(:ohai_json) { ohai_data.to_json }
  let(:tmpdir) { Dir.mktmpdir }
  let(:tmp_cache_dir) { File.join(tmpdir, "tmp") }

  before do
    FileUtils.mkdir_p(tmp_cache_dir)
    allow(Fauxhai).to receive(:root).and_return(tmpdir)
  end

  after { FileUtils.remove_entry(tmpdir) }

  # Helper to write a cache file for a given host/user
  def write_cache_for(host:, user:)
    key = Digest::SHA2.hexdigest("#{user}@#{host}")
    path = File.join(tmp_cache_dir, key)
    File.write(path, ohai_json)
    path
  end

  describe "#initialize" do
    context "with cached data (cache hit)" do
      it "loads data from cache without SSH" do
        write_cache_for(host: "myhost", user: "myuser")

        fetcher = described_class.new(host: "myhost", user: "myuser")
        expect(fetcher.to_hash).to eq(ohai_data)
      end
    end

    context "with cache miss (SSH path)" do
      let(:ssh_session) { instance_double("Net::SSH::Connection::Session") }

      before do
        stub_const("Net::SSH", Class.new)
        allow(Net::SSH).to receive(:start).and_yield(ssh_session)
        allow(ssh_session).to receive(:exec!).with("ohai").and_return(ohai_json)
      end

      it "fetches data via SSH and caches it" do
        fetcher = described_class.new(host: "newhost", user: "sshuser")

        expect(fetcher.to_hash).to eq(ohai_data)
        # Verify cache was written
        expect(fetcher.cached?).to be true
        expect(JSON.parse(File.read(fetcher.cache_file))).to eq(ohai_data)
      end
    end

    context "with force_cache_miss" do
      let(:ssh_session) { instance_double("Net::SSH::Connection::Session") }

      before do
        # Pre-populate cache with stale data
        write_cache_for(host: "refreshhost", user: "refreshuser")
        stub_const("Net::SSH", Class.new)
        allow(Net::SSH).to receive(:start).and_yield(ssh_session)
        allow(ssh_session).to receive(:exec!).with("ohai").and_return({ "platform" => "fresh" }.to_json)
      end

      it "bypasses cache and fetches via SSH" do
        fetcher = described_class.new(host: "refreshhost", user: "refreshuser", force_cache_miss: true)
        expect(fetcher.to_hash["platform"]).to eq("fresh")
      end
    end

    context "with a block" do
      it "yields the data to the block" do
        write_cache_for(host: "blockhost", user: "blockuser")

        yielded = nil
        described_class.new(host: "blockhost", user: "blockuser") { |d| yielded = d }
        expect(yielded).to eq(ohai_data)
      end
    end

    context "without :host" do
      it "raises ArgumentError" do
        expect { described_class.new(user: "nohost") }.to raise_error(ArgumentError, /:host is a required option/)
      end
    end
  end

  describe "#cache" do
    it "returns parsed JSON from the cache file" do
      write_cache_for(host: "cachehost", user: "cacheuser")
      fetcher = described_class.new(host: "cachehost", user: "cacheuser")
      expect(fetcher.cache).to eq(ohai_data)
    end
  end

  describe "#cached?" do
    it "returns true when cache file exists" do
      write_cache_for(host: "existhost", user: "existuser")
      fetcher = described_class.new(host: "existhost", user: "existuser")
      expect(fetcher.cached?).to be true
    end

    it "returns false when cache file does not exist" do
      # We need to construct a fetcher that was cached, then remove the file
      write_cache_for(host: "gonehost", user: "goneuser")
      fetcher = described_class.new(host: "gonehost", user: "goneuser")
      File.delete(fetcher.cache_file)
      expect(fetcher.cached?).to be false
    end
  end

  describe "#cache_key" do
    it "returns a SHA2 hex digest of user@host" do
      write_cache_for(host: "keyhost", user: "keyuser")
      fetcher = described_class.new(host: "keyhost", user: "keyuser")
      expected = Digest::SHA2.hexdigest("keyuser@keyhost")
      expect(fetcher.cache_key).to eq(expected)
    end
  end

  describe "#cache_file" do
    it "returns a path under Fauxhai.root/tmp/" do
      write_cache_for(host: "pathhost", user: "pathuser")
      fetcher = described_class.new(host: "pathhost", user: "pathuser")
      expect(fetcher.cache_file).to start_with(File.join(tmpdir, "tmp"))
    end
  end

  describe "#to_hash" do
    it "returns the data as a hash" do
      write_cache_for(host: "hashhost", user: "hashuser")
      fetcher = described_class.new(host: "hashhost", user: "hashuser")
      expect(fetcher.to_hash).to be_a(Hash)
      expect(fetcher.to_hash).to eq(ohai_data)
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      write_cache_for(host: "strhost", user: "struser")
      fetcher = described_class.new(host: "strhost", user: "struser")
      expect(fetcher.to_s).to match(/#<Fauxhai::Fetcher @host=strhost/)
    end
  end

  describe "#force_cache_miss?" do
    it "returns false by default" do
      write_cache_for(host: "defaulthost", user: "defaultuser")
      fetcher = described_class.new(host: "defaulthost", user: "defaultuser")
      expect(fetcher.force_cache_miss?).to be false
    end

    it "returns true when option is set" do
      ssh_session = instance_double("Net::SSH::Connection::Session")
      stub_const("Net::SSH", Class.new)
      allow(Net::SSH).to receive(:start).and_yield(ssh_session)
      allow(ssh_session).to receive(:exec!).with("ohai").and_return(ohai_json)

      fetcher = described_class.new(host: "forcehost", user: "forceuser", force_cache_miss: true)
      expect(fetcher.force_cache_miss?).to be true
    end
  end

  describe "user fallback" do
    it "falls back to ENV['USER'] when :user not provided" do
      write_cache_for(host: "envhost", user: ENV["USER"])
      fetcher = described_class.new(host: "envhost")
      expected_key = Digest::SHA2.hexdigest("#{ENV["USER"]}@envhost")
      expect(fetcher.cache_key).to eq(expected_key)
    end
  end
end
