require "spec_helper"
require "net/http"
require "tmpdir"
require "fileutils"

# ==========================================================================
# Contract tests for the Fauxhai public API boundaries.
#
# These tests verify the *shape* of data crossing each boundary — return
# types, required keys, round-trip integrity — rather than specific values.
# They act as a safety net so that internal refactors cannot silently break
# downstream consumers (ChefSpec, custom test helpers, etc.).
#
# == Validation process
#   1. Run:  bundle exec rspec spec/contract_spec.rb
#   2. All examples must pass before merging any change to lib/fauxhai/.
#   3. If a contract test fails after a code change, decide whether the
#      change is intentional (update the contract) or a regression (fix it).
#
# == Update guidance
#   - When adding a new platform JSON, no contract change needed — the
#     "all bundled platforms" loop picks it up automatically.
#   - When changing the return shape of Mocker#data or Fetcher#to_hash,
#     update the contract assertions below and note the breaking change.
#   - When adding a new public method to Fetcher/Mocker, add a contract
#     test here covering its return type and edge cases.
#
# == Rationale for each test group
#   See inline comments prefixed with "Rationale:".
# ==========================================================================

RSpec.describe "API contract tests" do

  # --------------------------------------------------------------------------
  # Boundary 1: Fauxhai::Mocker — the primary public interface
  # --------------------------------------------------------------------------
  describe "Fauxhai::Mocker data contract" do

    # Rationale: Mocker#data is the most-used public method. Downstream
    # consumers (ChefSpec, custom test helpers) always expect a Hash with
    # at least "platform" and "platform_version" keys. If either is missing
    # or the type changes, tests across the Chef ecosystem will break.
    context "return type and required keys" do
      subject(:data) do
        Fauxhai::Mocker.new(
          platform: "ubuntu", version: "20.04", github_fetching: false
        ).data
      end

      it "returns a Hash" do
        expect(data).to be_a(Hash)
      end

      it "contains 'platform' key as a non-empty String" do
        expect(data["platform"]).to be_a(String)
        expect(data["platform"]).not_to be_empty
      end

      it "contains 'platform_version' key as a non-empty String" do
        expect(data["platform_version"]).to be_a(String)
        expect(data["platform_version"]).not_to be_empty
      end
    end

    # Rationale: Every bundled platform JSON is a public contract — if any
    # file fails to parse or lacks the required keys, end users hit cryptic
    # errors. This loop ensures all shipped data meets the contract.
    context "all bundled platform JSON files" do
      platforms_dir = File.join(Fauxhai.root, "lib", "fauxhai", "platforms")
      json_files = Dir.glob(File.join(platforms_dir, "**", "*.json"))

      json_files.each do |json_path|
        relative = json_path.sub("#{platforms_dir}/", "")

        it "#{relative} parses to a Hash with 'platform' key" do
          data = JSON.parse(File.read(json_path))
          expect(data).to be_a(Hash)
          # The chefspec pseudo-platform has different keys
          next if relative.start_with?("chefspec/")

          expect(data).to have_key("platform"),
            "#{relative} is missing 'platform' key"
          expect(data).to have_key("platform_version"),
            "#{relative} is missing 'platform_version' key"
        end
      end
    end

    # Rationale: Calling Mocker without :platform is a common mistake.
    # The contract is that it falls back to "chefspec" platform and emits a warning,
    # NOT that it raises. If this changes, it would be a breaking change.
    # Note: the chefspec pseudo-platform JSON uses "hostname" => "chefspec"
    # as its identifier rather than a "platform" key.
    context "no-platform fallback contract" do
      it "falls back to 'chefspec' platform and warns via logger" do
        expect(Fauxhai.logger).to receive(:warn).with(/platform/)
        mocker = Fauxhai::Mocker.new(github_fetching: false)
        expect(mocker.data["hostname"]).to eq("chefspec")
      end
    end

    # Rationale: Version prefix matching is an implicit contract — users
    # pass partial versions (e.g. "7") and expect the best match. The \D
    # guard prevents "7" from matching "7.10" incorrectly. This test
    # validates the guard works on multi-version platforms.
    context "version prefix matching contract" do
      it "does not match '7.1' against '7.10' due to \\D guard" do
        # CentOS has 7.7.1908 and 7.8.2003 — "7.1" should NOT match 7.10
        # (which doesn't exist) but also should NOT match 7.7 or 7.8
        version = Fauxhai::Mocker.new(
          platform: "centos", version: "7.7", github_fetching: false
        ).send(:version)
        expect(version).to eq("7.7.1908")
      end

      it "prefix '7' matches the highest 7.x version" do
        version = Fauxhai::Mocker.new(
          platform: "centos", version: "7", github_fetching: false
        ).send(:version)
        expect(version).to eq("7.8.2003")
      end

      it "exact version takes priority over prefix match" do
        # Windows "2012" is both an exact file and a prefix of "2012R2"
        version = Fauxhai::Mocker.new(
          platform: "windows", version: "2012", github_fetching: false
        ).send(:version)
        expect(version).to eq("2012")
      end
    end
  end

  # --------------------------------------------------------------------------
  # Boundary 2: Fauxhai::Fetcher — SSH data collection
  # --------------------------------------------------------------------------
  describe "Fauxhai::Fetcher cache round-trip contract" do
    let(:ohai_data) do
      { "platform" => "ubuntu", "platform_version" => "22.04",
        "hostname" => "roundtrip", "languages" => { "ruby" => { "version" => "3.2" } } }
    end
    let(:ohai_json) { ohai_data.to_json }
    let(:tmpdir) { Dir.mktmpdir }
    let(:ssh_session) { instance_double("Net::SSH::Connection::Session") }

    before do
      FileUtils.mkdir_p(File.join(tmpdir, "tmp"))
      allow(Fauxhai).to receive(:root).and_return(tmpdir)
      stub_const("Net::SSH", Class.new)
      allow(Net::SSH).to receive(:start).and_yield(ssh_session)
      allow(ssh_session).to receive(:exec!).with("ohai").and_return(ohai_json)
    end

    after { FileUtils.remove_entry(tmpdir) }

    # Rationale: The core Fetcher contract is that data survives the
    # SSH → JSON.parse → CacheManager.write → CacheManager.read cycle
    # without any mutation. If serialisation changes (e.g. to MessagePack),
    # this test catches data loss immediately.
    it "SSH fetch → cache write → cache read produces identical data" do
      # First instantiation: SSH fetch + write to cache
      fetcher1 = Fauxhai::Fetcher.new(host: "rt-host", user: "rt-user")
      original = fetcher1.to_hash

      # Prevent further SSH calls — second instantiation must use cache
      allow(Net::SSH).to receive(:start).and_raise("Should not SSH again")

      # Second instantiation: cache hit
      fetcher2 = Fauxhai::Fetcher.new(host: "rt-host", user: "rt-user")
      cached = fetcher2.to_hash

      expect(cached).to eq(original)
      expect(cached).to eq(ohai_data)
    end

    # Rationale: to_hash is the public accessor — it must always return a
    # Hash, never nil or a String. Downstream code does `data["platform"]`.
    it "#to_hash always returns a Hash" do
      fetcher = Fauxhai::Fetcher.new(host: "type-host", user: "type-user")
      expect(fetcher.to_hash).to be_a(Hash)
    end
  end

  # --------------------------------------------------------------------------
  # Boundary 3: Fauxhai::CacheManager — internal but critical
  # --------------------------------------------------------------------------
  describe "Fauxhai::CacheManager round-trip contract" do
    let(:tmpdir) { Dir.mktmpdir }

    after { FileUtils.remove_entry(tmpdir) }

    # Rationale: CacheManager is the serialisation boundary between in-memory
    # Hashes and on-disk JSON. Any data that goes through write → read must
    # come back identical. This is the foundational contract that Fetcher and
    # Mocker depend on.
    it "write_json_file + read_json_file round-trips a Hash without data loss" do
      path = File.join(tmpdir, "roundtrip.json")
      original = {
        "platform" => "ubuntu",
        "platform_version" => "24.04",
        "nested" => { "deep" => [1, 2, 3] },
        "unicode" => "café ☕",
        "null_value" => nil,
        "bool" => true,
      }

      Fauxhai::CacheManager.write_json_file(path, original)
      restored = Fauxhai::CacheManager.read_json_file(path)

      expect(restored).to eq(original)
    end

    # Rationale: Mocker passes raw JSON strings (from GitHub HTTP response)
    # to write_json_file. The string must survive unchanged so that
    # parse_and_validate can process it on the next read.
    it "write_json_file with a String + read_json_file round-trips correctly" do
      path = File.join(tmpdir, "string_rt.json")
      original_hash = { "platform" => "test", "hostname" => "strrt" }
      json_string = original_hash.to_json

      Fauxhai::CacheManager.write_json_file(path, json_string)
      restored = Fauxhai::CacheManager.read_json_file(path)

      expect(restored).to eq(original_hash)
    end
  end
end
