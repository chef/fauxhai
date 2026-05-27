require "spec_helper"
require_relative "../scripts/generate_architecture_diagram"
require "tmpdir"

RSpec.describe Fauxhai::ArchitectureGenerator do
  describe ".scan_source_files" do
    subject(:files) { described_class.scan_source_files }

    it "returns an array of SourceFile structs" do
      expect(files).to be_an(Array)
      expect(files).to all(be_a(Fauxhai::ArchitectureGenerator::SourceFile))
    end

    it "discovers the core library files" do
      basenames = files.map(&:basename)
      %w[mocker fetcher runner exception version].each do |name|
        expect(basenames).to include(name), "expected to find #{name}.rb"
      end
    end

    it "extracts classes from source files" do
      mocker = files.find { |f| f.basename == "mocker" }
      expect(mocker.classes).to include("Mocker")
    end

    it "extracts modules from source files" do
      exception = files.find { |f| f.basename == "exception" }
      expect(exception.modules).to include("Exception")
    end

    it "extracts require statements" do
      fetcher = files.find { |f| f.basename == "fetcher" }
      expect(fetcher.requires).to include("digest/sha1")
    end
  end

  describe ".scan_platforms" do
    subject(:platforms) { described_class.scan_platforms }

    it "returns a hash of platform names to version arrays" do
      expect(platforms).to be_a(Hash)
      expect(platforms.keys).to include("ubuntu", "centos", "windows")
    end

    it "excludes the chefspec pseudo-platform" do
      expect(platforms.keys).not_to include("chefspec")
    end

    it "excludes the runner directory" do
      expect(platforms.keys).not_to include("runner")
    end

    it "lists version strings for each platform" do
      expect(platforms["ubuntu"]).to be_an(Array)
      expect(platforms["ubuntu"]).to include("20.04")
    end
  end

  describe ".generate" do
    let(:tmpdir) { Dir.mktmpdir }
    let(:output_path) { File.join(tmpdir, "ARCHITECTURE.md") }

    after { FileUtils.remove_entry(tmpdir) }

    subject(:markdown) do
      described_class.generate(output_path: output_path, write: true)
    end

    before do
      ENV["FAUXHAI_SILENT"] = "1"
    end

    after do
      ENV.delete("FAUXHAI_SILENT")
    end

    it "returns a non-empty string" do
      expect(markdown).to be_a(String)
      expect(markdown.length).to be > 100
    end

    it "writes the file to the given path" do
      markdown
      expect(File.exist?(output_path)).to be true
      expect(File.read(output_path)).to eq(markdown)
    end

    it "contains the Mermaid component diagram" do
      expect(markdown).to include("```mermaid")
      expect(markdown).to include("graph TD")
    end

    it "contains the sequence diagram" do
      expect(markdown).to include("sequenceDiagram")
    end

    it "contains the platform summary table" do
      expect(markdown).to include("## Platform Data Summary")
      expect(markdown).to include("| ubuntu |")
    end

    it "contains the module descriptions section" do
      expect(markdown).to include("## Module Descriptions")
      expect(markdown).to include("Fauxhai::Mocker")
    end

    it "contains generation metadata" do
      expect(markdown).to include("## Generation Info")
      expect(markdown).to include("scripts/generate_architecture_diagram.rb")
    end

    it "is idempotent — running twice produces same structure" do
      first = described_class.generate(output_path: output_path, write: false)
      second = described_class.generate(output_path: output_path, write: false)
      # Strip the timestamp line for comparison since time changes
      strip_ts = ->(s) { s.gsub(/\*\*Generated at:\*\* .+$/, "") }
      expect(strip_ts.call(first)).to eq(strip_ts.call(second))
    end
  end

  describe ".generate with write: false" do
    it "does not write a file" do
      tmpdir = Dir.mktmpdir
      output_path = File.join(tmpdir, "should_not_exist.md")
      ENV["FAUXHAI_SILENT"] = "1"
      described_class.generate(output_path: output_path, write: false)
      expect(File.exist?(output_path)).to be false
      ENV.delete("FAUXHAI_SILENT")
      FileUtils.remove_entry(tmpdir)
    end
  end

  describe ".parse_ruby_file" do
    let(:tmpdir) { Dir.mktmpdir }
    let(:test_file) { File.join(tmpdir, "test_class.rb") }

    before do
      File.write(test_file, <<~RUBY)
        require "json"
        require_relative "helper"

        module TestModule
          class TestClass
            def hello; end
          end
        end
      RUBY
    end

    after { FileUtils.remove_entry(tmpdir) }

    it "extracts requires, classes, and modules" do
      result = described_class.parse_ruby_file(test_file)
      expect(result.requires).to include("json", "helper")
      expect(result.classes).to include("TestClass")
      expect(result.modules).to include("TestModule")
    end
  end
end
