# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Fauxhai::CacheManager do
  let(:tmpdir) { Dir.mktmpdir }

  after { FileUtils.remove_entry(tmpdir) }

  describe ".read_json_file" do
    it "parses a valid JSON file and returns a Hash" do
      path = File.join(tmpdir, "test.json")
      File.write(path, '{"key": "value", "num": 42}')

      result = described_class.read_json_file(path)
      expect(result).to eq("key" => "value", "num" => 42)
    end

    it "raises Errno::ENOENT for a nonexistent file" do
      expect do
        described_class.read_json_file(File.join(tmpdir, "nope.json"))
      end.to raise_error(Errno::ENOENT)
    end

    it "raises JSON::ParserError for invalid JSON" do
      path = File.join(tmpdir, "bad.json")
      File.write(path, "not json {{{")

      expect do
        described_class.read_json_file(path)
      end.to raise_error(JSON::ParserError)
    end
  end

  describe ".write_json_file" do
    it "writes a Hash as pretty JSON" do
      path = File.join(tmpdir, "out.json")
      described_class.write_json_file(path, { "a" => 1 })

      expect(File.exist?(path)).to be true
      expect(JSON.parse(File.read(path))).to eq("a" => 1)
    end

    it "writes a raw String as-is" do
      path = File.join(tmpdir, "raw.json")
      raw = '{"raw": true}'
      described_class.write_json_file(path, raw)

      expect(File.read(path)).to eq(raw)
    end

    it "creates parent directories if they do not exist" do
      path = File.join(tmpdir, "deep", "nested", "dir", "file.json")
      described_class.write_json_file(path, { "nested" => true })

      expect(File.exist?(path)).to be true
      expect(JSON.parse(File.read(path))).to eq("nested" => true)
    end

    it "overwrites an existing file" do
      path = File.join(tmpdir, "overwrite.json")
      described_class.write_json_file(path, { "v" => 1 })
      described_class.write_json_file(path, { "v" => 2 })

      expect(JSON.parse(File.read(path))).to eq("v" => 2)
    end
  end
end
